import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule public members of public types', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_public_member_exemption_test_',
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

    group('outside lib/src/', () {
      test(
        'does not flag a public instance method on a public class under lib/',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'thing.dart'):
                'class Thing {\n  void doWork() {}\n}\n',
          });
          expect(diagnostics, isEmpty);
        },
      );

      test(
        'does not flag a public static method on a public class under lib/',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'thing.dart'):
                'class Thing {\n  static int compute() => 0;\n}\n',
          });
          expect(diagnostics, isEmpty);
        },
      );

      test(
        'does not flag a public getter/setter on a public class under lib/',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'thing.dart'):
                'class Thing {\n'
                '  int get value => 0;\n'
                '  set value(int v) {}\n'
                '}\n',
          });
          expect(diagnostics, isEmpty);
        },
      );

      test(
        'does not flag a public method on a public mixin under lib/',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'thing.dart'):
                'mixin Loggable {\n  void log() {}\n}\n',
          });
          expect(diagnostics, isEmpty);
        },
      );

      test(
        'does not flag a public method on a public enum under lib/',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'thing.dart'):
                'enum Color {\n  red,\n  green;\n\n'
                '  String describe() => name;\n'
                '}\n',
          });
          expect(diagnostics, isEmpty);
        },
      );

      test(
        'does not flag a public method on a public extension type under lib/',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'thing.dart'):
                'extension type Id(int value) {\n'
                '  int get next => value + 1;\n'
                '}\n',
          });
          expect(diagnostics, isEmpty);
        },
      );

      test(
        'does not flag a public member on a public extension under lib/',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'thing.dart'):
                'extension StringExtras on String {\n'
                '  int get doubledLength => length * 2;\n'
                '}\n',
          });
          expect(diagnostics, isEmpty);
        },
      );

      test(
        'still flags a private member of a public class under lib/',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'thing.dart'):
                'class Thing {\n  void _helper() {}\n}\n',
          });
          expect(diagnostics, hasLength(1));
          final diagnostic = diagnostics.single;
          expect(diagnostic.ruleId, 'unused_function');
          expect(diagnostic.message, contains('_helper'));
        },
      );

      test(
        'still flags a public member of a private class under lib/',
        () async {
          // The private type is instantiated so `unused_class` would not
          // already flag it (which would suppress member reports); only the
          // unreferenced public member should remain.
          final diagnostics = await runRule({
            p.join('lib', 'thing.dart'):
                'class _Thing {\n  void doWork() {}\n}\n'
                '_Thing build() => _Thing();\n',
          });
          expect(diagnostics, hasLength(1));
          final diagnostic = diagnostics.single;
          expect(diagnostic.ruleId, 'unused_function');
          expect(diagnostic.message, contains('doWork'));
        },
      );
    });

    group('under lib/src/', () {
      test(
        'flags an unreferenced public instance method on a public class',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'src', 'thing.dart'):
                'class Thing {\n  void doWork() {}\n}\n',
          });
          expect(diagnostics, hasLength(1));
          final diagnostic = diagnostics.single;
          expect(diagnostic.ruleId, 'unused_function');
          expect(diagnostic.message, contains('doWork'));
        },
      );

      test(
        'flags an unreferenced public member on a public extension',
        () async {
          final diagnostics = await runRule({
            p.join('lib', 'src', 'thing.dart'):
                'extension StringExtras on String {\n'
                '  int get doubledLength => length * 2;\n'
                '}\n',
          });
          expect(diagnostics, hasLength(1));
          final diagnostic = diagnostics.single;
          expect(diagnostic.ruleId, 'unused_function');
          expect(diagnostic.message, contains('doubledLength'));
        },
      );

      test('does not flag a public method referenced from elsewhere', () async {
        final diagnostics = await runRule({
          p.join('lib', 'src', 'thing.dart'):
              'class Thing {\n  void doWork() {}\n}\n',
          p.join('lib', 'pkg.dart'):
              "import 'src/thing.dart';\n"
              'void use() {\n  Thing().doWork();\n}\n',
        });
        expect(diagnostics, isEmpty);
      });
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
