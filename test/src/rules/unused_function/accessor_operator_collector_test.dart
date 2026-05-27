import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule — accessor/operator collector', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_accessor_operator_test_',
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

    test('flags an unused getter', () async {
      final diagnostics = await runRule('''
class C {
  int get x => 1;
}
void main() {}
''');
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('x'));
      expect(diagnostics.single.message, contains('getter'));
    });

    test('does not flag a getter referenced via property access', () async {
      final diagnostics = await runRule('''
class C {
  int get x => 1;
}
void main() {
  C().x;
}
''');
      expect(diagnostics, isEmpty);
    });

    test('flags an unused setter', () async {
      final diagnostics = await runRule('''
class C {
  set x(int v) {}
}
void main() {}
''');
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('x'));
      expect(diagnostics.single.message, contains('setter'));
    });

    test('does not flag a setter referenced via assignment', () async {
      final diagnostics = await runRule('''
class C {
  set x(int v) {}
}
void main() {
  C().x = 1;
}
''');
      expect(diagnostics, isEmpty);
    });

    test('flags an unused operator', () async {
      final diagnostics = await runRule('''
class C {
  C operator +(C other) => this;
}
void main() {}
''');
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('+'));
      expect(diagnostics.single.message, contains('operator'));
    });

    test('does not flag a used operator', () async {
      final diagnostics = await runRule('''
class C {
  C operator +(C other) => this;
}
void main() {
  final a = C();
  final b = C();
  a + b;
}
''');
      expect(diagnostics, isEmpty);
    });

    test(
      'same-named getter and setter where only getter is used: setter flagged, '
      'getter not',
      () async {
        final diagnostics = await runRule('''
class C {
  int get x => 1;
  set x(int v) {}
}
void main() {
  C().x;
}
''');
        expect(diagnostics, hasLength(1));
        expect(diagnostics.single.message, contains('x'));
        expect(diagnostics.single.message, contains('setter'));
      },
    );

    test('does not flag a getter that overrides a supertype getter', () async {
      final diagnostics = await runRule('''
abstract class Base {
  int get x;
}
class C extends Base {
  @override
  int get x => 1;
}
void main() {
  Base b = C();
  b.x;
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
