import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule constructor collector', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_constructor_collector_test_',
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

    test('flags an unused named constructor', () async {
      final diagnostics = await runRule('''
class MyClass {
  MyClass();
  MyClass.named();
}
void main() {
  MyClass();
}
''');
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_function');
      expect(diagnostic.message, contains('named'));
      expect(diagnostic.message, contains('constructor'));
    });

    test('does not flag a used named constructor', () async {
      final diagnostics = await runRule('''
class MyClass {
  MyClass();
  MyClass.named();
}
void main() {
  MyClass();
  MyClass.named();
}
''');
      expect(diagnostics, isEmpty);
    });

    test('flags an unused factory constructor', () async {
      final diagnostics = await runRule('''
class MyClass {
  MyClass();
  factory MyClass.make() => MyClass();
}
void main() {
  MyClass();
}
''');
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('make'));
      expect(diagnostics.single.message, contains('constructor'));
    });

    test('does not flag a factory used as a redirect target', () async {
      final diagnostics = await runRule('''
class MyClass {
  MyClass.foo();
  factory MyClass() = MyClass.foo;
}
void main() {
  MyClass();
}
''');
      expect(diagnostics, isEmpty);
    });

    test('does not flag a generative redirect target', () async {
      final diagnostics = await runRule('''
class MyClass {
  MyClass.bar();
  MyClass.foo() : this.bar();
}
void main() {
  MyClass.foo();
}
''');
      expect(diagnostics, isEmpty);
    });

    test('counts a constructor tear-off as a use', () async {
      final diagnostics = await runRule('''
class MyClass {
  MyClass();
}
void main() {
  final make = MyClass.new;
  make();
}
''');
      expect(diagnostics, isEmpty);
    });

    test(
      'does not flag an unnamed default constructor invoked by MyClass()',
      () async {
        final diagnostics = await runRule('''
class MyClass {
  MyClass();
}
void main() {
  MyClass();
}
''');
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'does not additionally flag constructors of an unused private class',
      () async {
        final diagnostics = await runRule('''
class _UnusedClass {
  _UnusedClass();
  _UnusedClass.named();
}
void main() {}
''');
        for (final diagnostic in diagnostics) {
          expect(diagnostic.message, isNot(contains('constructor')));
        }
      },
    );

    test('skips constructors annotated with @pragma(vm:entry-point)', () async {
      final diagnostics = await runRule('''
class MyClass {
  MyClass();
  @pragma('vm:entry-point')
  MyClass.named();
}
void main() {
  MyClass();
}
''');
      expect(diagnostics, isEmpty);
    });

    test('skips external constructors', () async {
      final diagnostics = await runRule('''
class MyClass {
  MyClass();
  external MyClass.named();
}
void main() {
  MyClass();
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
