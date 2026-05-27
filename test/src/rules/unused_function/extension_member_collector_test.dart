import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule extension member collector', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_extension_member_collector_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<List<Diagnostic>> runRule(
      String content, {
      String fileName = 'fixture.dart',
    }) async {
      final fixture = File(p.join(tempDir.path, fileName));
      fixture.writeAsStringSync(content);

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

    test('flags an unused extension method', () async {
      final diagnostics = await runRule('''
extension StringX on String {
  int countX() => 0;
}
void main() {}
''');
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_function');
      expect(diagnostic.message, contains('countX'));
      expect(diagnostic.message, contains('extension method'));
    });

    test('does not flag a used extension method', () async {
      final diagnostics = await runRule('''
extension StringX on String {
  int countX() => 0;
}
void main() {
  ''.countX();
}
''');
      expect(diagnostics, isEmpty);
    });

    test('flags an unused extension getter', () async {
      final diagnostics = await runRule('''
extension StringX on String {
  int get widthX => 0;
}
void main() {}
''');
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.message, contains('widthX'));
      expect(diagnostic.message, contains('extension getter'));
    });

    test('flags an unused operator on an extension', () async {
      final diagnostics = await runRule('''
extension StringX on String {
  String operator *(int n) => this;
}
void main() {}
''');
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.message, contains('*'));
      expect(diagnostic.message, contains('extension operator'));
    });

    test('flags an unused method on an extension type', () async {
      final diagnostics = await runRule('''
extension type Meters(int value) {
  int doubled() => value * 2;
}
void main() {}
''');
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.message, contains('doubled'));
      expect(diagnostic.message, contains('extension type method'));
    });

    test('does not flag a used method on an extension type', () async {
      final diagnostics = await runRule('''
extension type Meters(int value) {
  int doubled() => value * 2;
}
void main() {
  Meters(1).doubled();
}
''');
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
