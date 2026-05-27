import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule top-level accessor collector', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_top_level_accessor_collector_test_',
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
      paths.sort();

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

    test('flags an unused private top-level getter', () async {
      final diagnostics = await runRule({
        'fixture.dart': 'int get _foo => 1;\nvoid main() {}\n',
      });
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_function');
      expect(diagnostic.message, contains('_foo'));
      expect(diagnostic.message, contains('top-level getter'));
    });

    test('flags an unused private top-level setter', () async {
      final diagnostics = await runRule({
        'fixture.dart': 'set _foo(int value) {}\nvoid main() {}\n',
      });
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_function');
      expect(diagnostic.message, contains('_foo'));
      expect(diagnostic.message, contains('top-level setter'));
    });

    test(
      'a read of a top-level getter from another file is treated as a use',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'src', 'source.dart'): 'int get foo => 1;\n',
          p.join('lib', 'src', 'user.dart'):
              "import 'source.dart';\nvoid main() { foo; }\n",
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'an assignment to a top-level setter from another file is treated as a '
      'use',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'src', 'source.dart'): 'set foo(int value) {}\n',
          p.join('lib', 'src', 'user.dart'):
              "import 'source.dart';\nvoid main() { foo = 1; }\n",
        });
        expect(diagnostics, isEmpty);
      },
    );

    test('libraries with part files exempt top-level accessors', () async {
      final diagnostics = await runRule({
        'fixture.dart':
            "part 'fixture_part.dart';\n"
            'int get _foo => 1;\n'
            'set _bar(int value) {}\n'
            'void main() {}\n',
        'fixture_part.dart': "part of 'fixture.dart';\n",
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
