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
      fixture.parent.createSync(recursive: true);
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
      // Under lib/src/ a public extension member is still flaggable; the
      // public-API exemption only applies outside lib/src/.
      final diagnostics = await runRule('''
extension StringX on String {
  void hello() {}
}
void main() {}
''', fileName: p.join('lib', 'src', 'fixture.dart'));
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_function');
      expect(diagnostic.message, contains('hello'));
      expect(diagnostic.message, contains('extension method'));
    });

    test('does not flag an extension method invoked on a receiver', () async {
      final diagnostics = await runRule('''
extension StringX on String {
  void hello() {}
}
void main() {
  ''.hello();
}
''');
      expect(diagnostics, isEmpty);
    });

    test('does not flag an extension operator used in an expression', () async {
      final diagnostics = await runRule('''
class Box {
  const Box();
}
extension BoxX on Box {
  Box operator +(Box other) => this;
}
void main() {
  const Box() + const Box();
}
''');
      expect(diagnostics, isEmpty);
    });

    test('flags an unused extension getter', () async {
      // Under lib/src/ a public extension member is still flaggable; the
      // public-API exemption only applies outside lib/src/.
      final diagnostics = await runRule('''
extension StringX on String {
  int get length2 => 0;
}
void main() {}
''', fileName: p.join('lib', 'src', 'fixture.dart'));
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.message, contains('length2'));
      expect(diagnostic.message, contains('extension getter'));
    });

    test(
      'does not additionally flag members of an unused private extension',
      () async {
        final diagnostics = await runRule('''
extension _Priv on String {
  void hello() {}
}
void main() {}
''');
        for (final diagnostic in diagnostics) {
          expect(diagnostic.message, isNot(contains('extension')));
        }
      },
    );
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
