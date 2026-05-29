import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule class member collector', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_class_member_collector_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<List<Diagnostic>> runRule(
      Map<String, String> files, {
      String entryFileName = 'fixture.dart',
    }) async {
      assert(files.isNotEmpty, 'at least one file must be provided');
      files.forEach((name, content) {
        File(p.join(tempDir.path, name)).writeAsStringSync(content);
      });

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

    test('flags an unused private method', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  void _unused() {}
}
void main() {
  C();
}
''',
      });
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_function');
      expect(diagnostic.message, contains('_unused'));
      expect(diagnostic.message, contains('method'));
    });

    test('flags an unused static method', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  static void _unused() {}
}
void main() {
  C();
}
''',
      });
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('_unused'));
      expect(diagnostics.single.message, contains('static method'));
    });

    test('flags an unused getter', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  int get _value => 1;
}
void main() {
  C();
}
''',
      });
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('_value'));
      expect(diagnostics.single.message, contains('getter'));
    });

    test('flags an unused setter', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  set _value(int v) {}
}
void main() {
  C();
}
''',
      });
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('_value'));
      expect(diagnostics.single.message, contains('setter'));
    });

    test('flags an unused operator', () async {
      // The enclosing type is private (but referenced) so the public
      // operator is not exempted as part of a public type's API surface.
      final diagnostics = await runRule({
        'fixture.dart': '''
class _C {
  _C operator +(_C other) => this;
}
void main() {
  _C();
}
''',
      });
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('+'));
      expect(diagnostics.single.message, contains('operator'));
    });

    test('does not flag a method used via an instance call', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  void doIt() {}
}
void main() {
  C().doIt();
}
''',
      });
      expect(diagnostics, isEmpty);
    });

    test('does not flag a getter that is read', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  int get value => 1;
}
void main() {
  C().value;
}
''',
      });
      expect(diagnostics, isEmpty);
    });

    test('does not flag a setter that is written', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  set value(int v) {}
}
void main() {
  C().value = 5;
}
''',
      });
      expect(diagnostics, isEmpty);
    });

    test('does not flag an operator used via "a + b"', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  C operator +(C other) => this;
}
void main() {
  final a = C();
  final b = C();
  a + b;
}
''',
      });
      expect(diagnostics, isEmpty);
    });

    test('counts a method tear-off as a use', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  void doIt() {}
}
void main() {
  final f = C().doIt;
  f();
}
''',
      });
      expect(diagnostics, isEmpty);
    });

    test(
      'does not flag a base method called via super from a subclass',
      () async {
        final diagnostics = await runRule({
          'fixture.dart': '''
class A {
  void doIt() {}
}
class B extends A {
  @override
  void doIt() {
    super.doIt();
  }
}
void main() {
  B().doIt();
}
''',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test('does not flag a base method when its overriding method in another '
        'file is called', () async {
      final diagnostics = await runRule({
        'base.dart': '''
class A {
  void doIt() {}
}
''',
        'sub.dart': '''
import 'base.dart';
class B extends A {
  @override
  void doIt() {}
}
''',
        'fixture.dart': '''
import 'base.dart';
import 'sub.dart';
void main() {
  A().doIt();
  B().doIt();
}
''',
      });
      expect(diagnostics, isEmpty);
    });

    test('skips members annotated with @pragma(vm:entry-point)', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  @pragma('vm:entry-point')
  void _unused() {}
}
void main() {
  C();
}
''',
      });
      expect(diagnostics, isEmpty);
    });

    test('skips external members', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class C {
  external void _unused();
}
void main() {
  C();
}
''',
      });
      expect(diagnostics, isEmpty);
    });

    // Invariant: unused_function must not double-report a member of a type
    // that unused_class already flags. unused_class only flags PRIVATE,
    // unreferenced class/mixin/enum/extension-type declarations, so for those
    // the entire member surface is suppressed here — the rule reports nothing.
    group('does not double-report members of an unused private type', () {
      test(
        'class members (method, static, getter, setter, operator)',
        () async {
          final diagnostics = await runRule({
            'fixture.dart': '''
class _UnusedClass {
  void _method() {}
  static void _staticMethod() {}
  int get _value => 1;
  set _value(int v) {}
  int operator +(int other) => other;
}
void main() {}
''',
          });
          // unused_class owns the report for `_UnusedClass`; unused_function
          // adds nothing. (Member signatures deliberately avoid naming
          // `_UnusedClass`, since doing so would make the class self-referenced
          // and thus not an "unused class" in the first place.)
          expect(diagnostics, isEmpty);
        },
      );

      test('mixin members', () async {
        final diagnostics = await runRule({
          'fixture.dart': '''
mixin _UnusedMixin {
  void _method() {}
  int get _value => 1;
}
void main() {}
''',
        });
        expect(diagnostics, isEmpty);
      });

      test('enum members', () async {
        final diagnostics = await runRule({
          'fixture.dart': '''
enum _UnusedEnum {
  a,
  b;

  void _method() {}
  int get _value => 1;
}
void main() {}
''',
        });
        expect(diagnostics, isEmpty);
      });

      test('extension-type members', () async {
        final diagnostics = await runRule({
          'fixture.dart': '''
extension type _UnusedId(int value) {
  void _method() {}
  int get _doubled => value * 2;
}
void main() {}
''',
        });
        expect(diagnostics, isEmpty);
      });

      test('constructors', () async {
        final diagnostics = await runRule({
          'fixture.dart': '''
class _UnusedClass {
  _UnusedClass();
  _UnusedClass.named();
}
void main() {}
''',
        });
        // The constructor collector routes through the same dispatch-site
        // exemption, so neither the unnamed nor the named constructor of an
        // unreferenced private class is reported.
        expect(diagnostics, isEmpty);
      });

      test('public members are suppressed too (exemption keys off the '
          'enclosing type, not member privacy)', () async {
        final diagnostics = await runRule({
          'fixture.dart': '''
class _UnusedClass {
  void publicMethod() {}
  int get publicGetter => 1;
}
void main() {}
''',
        });
        expect(diagnostics, isEmpty);
      });
    });

    test('positive control: members of a REFERENCED private class are still '
        'flagged, so the exemption does not mask real findings', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
class _C {
  void _unused() {}
}
void main() {
  _C();
}
''',
      });
      // `_C` is referenced (so unused_class does NOT flag it), which means
      // unused_function must still report its unreferenced member.
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('_unused'));
      expect(diagnostics.single.message, contains('method'));
    });

    test('flags an unused method declared on a mixin', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
mixin M {
  void _unused() {}
}
class C with M {}
void main() {
  C();
}
''',
      });
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('_unused'));
      expect(diagnostics.single.message, contains('method'));
    });

    test('flags an unused method declared on an enum', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
enum E {
  a, b;
  void _unused() {}
}
void main() {
  E.a;
}
''',
      });
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('_unused'));
      expect(diagnostics.single.message, contains('method'));
    });

    test('flags an unused method declared on an extension type', () async {
      final diagnostics = await runRule({
        'fixture.dart': '''
extension type ET(int value) {
  void _unused() {}
}
void main() {
  ET(1);
}
''',
      });
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('_unused'));
      expect(diagnostics.single.message, contains('method'));
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
