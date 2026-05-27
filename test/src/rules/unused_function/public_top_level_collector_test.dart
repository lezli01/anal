import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/entry_point_classifier.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule public top-level collector', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_public_top_level_collector_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<List<Diagnostic>> runRule(Map<String, String> files) async {
      for (final entry in files.entries) {
        final file = File(p.join(tempDir.path, entry.key));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
      }

      final dartFiles = <String>[
        for (final entity in tempDir.listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart'))
            p.normalize(p.absolute(entity.path)),
      ]..sort();

      final collection = AnalysisContextCollection(
        includedPaths: dartFiles,
        sdkPath: _resolveSdkPath(),
      );

      final units = <ResolvedUnitResult>[];
      for (final path in dartFiles) {
        final session = collection.contextFor(path).currentSession;
        final result = await session.getResolvedUnit(path);
        expect(result, isA<ResolvedUnitResult>());
        units.add(result as ResolvedUnitResult);
      }

      final context = MultiFileAnalysisContext(
        units: units,
        analyzedFilePaths: <String>{for (final u in units) u.path},
      );
      return const UnusedFunctionRule().analyze(context).toList();
    }

    test('flags unused public top-level function under lib/src', () async {
      final diagnostics = await runRule({
        p.join('lib', 'src', 'foo.dart'): 'void foo() {}\n',
        p.join('lib', 'api.dart'): 'void main() {}\n',
      });
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_function');
      expect(diagnostic.message, contains('foo'));
      expect(diagnostic.message, contains('public top-level'));
      expect(diagnostic.location.filePath, endsWith('foo.dart'));
    });

    test(
      'does not flag a public top-level function referenced from another file',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'src', 'foo.dart'): 'void foo() {}\n',
          p.join('lib', 'api.dart'):
              "import 'src/foo.dart';\n\nvoid main() { foo(); }\n",
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'never flags public top-level functions in lib/<root>.dart entry-point files',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'api.dart'): 'void publicApi() {}\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'never flags public top-level functions in bin entry-point files',
      () async {
        final diagnostics = await runRule({
          p.join('bin', 'tool.dart'): 'void helper() {}\nvoid main() {}\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'never flags public top-level functions in test entry-point files',
      () async {
        final diagnostics = await runRule({
          p.join('test', 'helpers.dart'): 'void buildFixture() {}\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'never flags top-level main even when the file is not an entry-point path',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'src', 'foo.dart'): 'void main() {}\n',
        });
        // The file declares `main`, so it is classified as an entry point and
        // `main` is exempt regardless.
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'skips external top-level functions in non-entry-point files',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'src', 'foo.dart'): 'external void unusedExt();\n',
          p.join('lib', 'api.dart'): 'void main() {}\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'skips functions annotated with @pragma(vm:entry-point)',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'src', 'foo.dart'):
              "@pragma('vm:entry-point')\nvoid pragmaEntry() {}\n",
          p.join('lib', 'api.dart'): 'void main() {}\n',
        });
        expect(diagnostics, isEmpty);
      },
    );
  });

  group('entry_point_classifier snapshot', () {
    // The shared `isEntryPointByPath` is extracted from a previously inlined
    // `_isEntryPointByPath` helper. These cases pin the documented behaviour
    // so future refactors of either copy stay in lockstep.
    test('files directly under lib/ are entry points', () {
      expect(isEntryPointByPath(p.join('lib', 'foo.dart')), isTrue);
      expect(isEntryPointByPath(p.join('lib', 'anal.dart')), isTrue);
    });

    test('files nested in lib/ subdirectories are not entry points', () {
      expect(isEntryPointByPath(p.join('lib', 'src', 'foo.dart')), isFalse);
      expect(
        isEntryPointByPath(p.join('lib', 'src', 'sub', 'foo.dart')),
        isFalse,
      );
    });

    test('any file under bin/ is an entry point', () {
      expect(isEntryPointByPath(p.join('bin', 'tool.dart')), isTrue);
      expect(isEntryPointByPath(p.join('bin', 'sub', 'tool.dart')), isTrue);
    });

    test('any file under test/ is an entry point', () {
      expect(isEntryPointByPath(p.join('test', 'foo_test.dart')), isTrue);
      expect(
        isEntryPointByPath(p.join('test', 'src', 'foo_test.dart')),
        isTrue,
      );
    });

    test('paths without a bin/test/lib anchor are not entry points', () {
      expect(isEntryPointByPath(p.join('other', 'foo.dart')), isFalse);
      expect(isEntryPointByPath('foo.dart'), isFalse);
    });

    test('the last anchor segment in the path wins', () {
      // A nested `lib` deep in the tree still anchors classification.
      expect(
        isEntryPointByPath(p.join('packages', 'pkg', 'lib', 'foo.dart')),
        isTrue,
      );
      expect(
        isEntryPointByPath(
          p.join('packages', 'pkg', 'lib', 'src', 'foo.dart'),
        ),
        isFalse,
      );
    });
  });
}

String? _resolveSdkPath() {
  final defaultPath = p.dirname(p.dirname(Platform.resolvedExecutable));
  if (_looksLikeSdk(defaultPath)) return defaultPath;

  var dir = p.dirname(Platform.resolvedExecutable);
  while (true) {
    final candidate = p.join(dir, 'bin', 'cache', 'dart-sdk');
    if (_looksLikeSdk(candidate)) return candidate;
    final parent = p.dirname(dir);
    if (parent == dir) return defaultPath;
    dir = parent;
  }
}

bool _looksLikeSdk(String sdkPath) {
  return FileSystemEntity.isFileSync(
    p.join(sdkPath, 'lib', '_internal', 'allowed_experiments.json'),
  );
}
