import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule public top-level functions', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_public_top_level_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<List<Diagnostic>> runRule(Map<String, String> files) async {
      final paths = <String>[];
      for (final entry in files.entries) {
        final file = File(p.join(tempDir.path, entry.key));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
        paths.add(p.normalize(p.absolute(file.path)));
      }

      final collection = AnalysisContextCollection(
        includedPaths: paths,
        sdkPath: _resolveSdkPath(),
      );

      final units = <ResolvedUnitResult>[];
      for (final path in paths) {
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

    test(
      'flags an unreferenced public top-level function in lib/src/',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'src', 'foo.dart'): 'void publicFn() {}\n',
        });
        expect(diagnostics, hasLength(1));
        final diagnostic = diagnostics.single;
        expect(diagnostic.ruleId, 'unused_function');
        expect(diagnostic.message, contains('publicFn'));
        expect(diagnostic.message, contains('top-level'));
        expect(
          diagnostic.location.filePath,
          p.normalize(
            p.absolute(p.join(tempDir.path, 'lib', 'src', 'foo.dart')),
          ),
        );
      },
    );

    test('does not flag a public top-level function in lib/src/ referenced '
        'from lib/', () async {
      final diagnostics = await runRule({
        p.join('lib', 'src', 'foo.dart'): 'void publicFn() {}\n',
        p.join('lib', 'pkg.dart'):
            "import 'src/foo.dart';\nvoid use() { publicFn(); }\n",
      });
      expect(diagnostics, isEmpty);
    });

    test(
      'does not flag a public top-level function directly under lib/',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'pkg.dart'): 'void publicFn() {}\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'does not flag a public top-level function under bin/ or test/',
      () async {
        final diagnostics = await runRule({
          p.join('bin', 'tool.dart'): 'void publicFn() {}\nvoid main() {}\n',
          p.join('test', 'thing_test.dart'): 'void publicHelper() {}\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test('does not flag main even when declared in lib/src/', () async {
      final diagnostics = await runRule({
        p.join('lib', 'src', 'foo.dart'): 'void main() {}\n',
      });
      expect(diagnostics, isEmpty);
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
