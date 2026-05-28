import 'dart:io';

import 'package:anal/src/analysis_context.dart';
import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/rules/unused_class_rule.dart';
import 'package:anal/src/severity.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedClassRule', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('unused_class_rule_test_');
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
      final filePath = p.normalize(p.absolute(fixture.path));
      final collection = AnalysisContextCollection(
        includedPaths: [filePath],
        sdkPath: _resolveSdkPath(),
      );
      final session = collection.contextFor(filePath).currentSession;
      final result = await session.getResolvedUnit(filePath);
      expect(result, isA<ResolvedUnitResult>());
      final resolved = result as ResolvedUnitResult;
      final context = AnalysisContext(unit: resolved, filePath: filePath);
      return const UnusedClassRule().analyze(context).toList();
    }

    test('reports unused top-level private class', () async {
      const source = 'class _Foo {}\nvoid main() {}\n';
      final diagnostics = await runRule(source);

      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_class');
      expect(diagnostic.severity, Severity.warning);
      expect(diagnostic.message, contains('_Foo'));
      expect(diagnostic.message, contains('class'));
      expect(diagnostic.location.offset, source.indexOf('_Foo'));
      expect(diagnostic.location.length, '_Foo'.length);
      expect(diagnostic.location.line, 1);
      expect(diagnostic.location.column, source.indexOf('_Foo') + 1);
    });

    test('does not report a used private class', () async {
      final diagnostics = await runRule(
        'class _Foo {}\nvoid main() { _Foo(); }\n',
      );
      expect(diagnostics, isEmpty);
    });

    test('counts a constructor tear-off as a use', () async {
      final diagnostics = await runRule(
        'class _Foo {}\nfinal f = _Foo.new;\nvoid main() { f(); }\n',
      );
      expect(diagnostics, isEmpty);
    });

    test('counts a type annotation as a use', () async {
      final diagnostics = await runRule(
        'class _Foo {}\nvoid main() { _Foo? x; x; }\n',
      );
      expect(diagnostics, isEmpty);
    });

    test('counts extends, implements, and with clauses as uses', () async {
      final diagnostics = await runRule('''
class _Base {}
abstract class _Iface {}
mixin _Mix {}
class C extends _Base implements _Iface with _Mix {}
void main() { C(); }
''');
      expect(diagnostics, isEmpty);
    });

    test('counts static-member access as a use', () async {
      final diagnostics = await runRule('''
class _Foo {
  static void bar() {}
}
void main() { _Foo.bar(); }
''');
      expect(diagnostics, isEmpty);
    });

    test('does not flag public top-level classes', () async {
      final diagnostics = await runRule('class Foo {}\nvoid main() {}\n');
      expect(diagnostics, isEmpty);
    });

    test('reports unused private mixin', () async {
      final diagnostics = await runRule('mixin _M {}\nvoid main() {}\n');
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_class');
      expect(diagnostic.message, contains('_M'));
      expect(diagnostic.message, contains('mixin'));
    });

    test('reports unused private enum', () async {
      final diagnostics = await runRule('enum _E { a, b }\nvoid main() {}\n');
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_class');
      expect(diagnostic.message, contains('_E'));
      expect(diagnostic.message, contains('enum'));
    });

    test('reports unused private extension type', () async {
      final diagnostics = await runRule(
        'extension type _ET(int value) {}\nvoid main() {}\n',
      );
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_class');
      expect(diagnostic.message, contains('_ET'));
      expect(diagnostic.message, contains('extension type'));
    });

    // Regression test for the analyzer 9.0.0 build break introduced when the
    // rule reached into `ExtensionTypeDeclaration.primaryConstructor` (an
    // analyzer 10+ API). The rule must still report unused private extension
    // types and still ignore ones that are used.
    test('analyzer 9.0.0 compatibility: flags unused but ignores used '
        'private extension type named _FooExt', () async {
      final unusedDiagnostics = await runRule(
        'extension type _FooExt(int value) {}\nvoid main() {}\n',
      );
      expect(unusedDiagnostics, hasLength(1));
      expect(unusedDiagnostics.single.message, contains('_FooExt'));
      expect(unusedDiagnostics.single.message, contains('extension type'));

      final usedDiagnostics = await runRule(
        'extension type _FooExt(int value) {}\n'
        'void main() { _FooExt(1); }\n',
      );
      expect(usedDiagnostics, isEmpty);
    });

    test('counts enum value access as a use of the enum', () async {
      final diagnostics = await runRule(
        'enum _E { a, b }\nvoid main() { _E.a; }\n',
      );
      expect(diagnostics, isEmpty);
    });

    test('counts an is check as a use', () async {
      final diagnostics = await runRule(
        'class _Foo {}\nvoid main() { Object o = 1; o is _Foo; }\n',
      );
      expect(diagnostics, isEmpty);
    });

    test('skips files in libraries that have parts', () async {
      File(
        p.join(tempDir.path, 'fixture_part.dart'),
      ).writeAsStringSync("part of 'fixture.dart';\n");
      final diagnostics = await runRule(
        "part 'fixture_part.dart';\nclass _Foo {}\nvoid main() {}\n",
      );
      expect(diagnostics, isEmpty);
    });

    test('skips classes annotated with @pragma(vm:entry-point)', () async {
      final diagnostics = await runRule(
        "@pragma('vm:entry-point')\nclass _Foo {}\nvoid main() {}\n",
      );
      expect(diagnostics, isEmpty);
    });

    test(
      'reports multiple unused declarations sorted by line and column',
      () async {
        final diagnostics = await runRule(
          'class _Foo {}\nmixin _Bar {}\nenum _Baz { a }\nvoid main() {}\n',
        );
        expect(diagnostics, hasLength(3));
        expect(diagnostics[0].message, contains('_Foo'));
        expect(diagnostics[1].message, contains('_Bar'));
        expect(diagnostics[2].message, contains('_Baz'));
        expect(
          diagnostics[0].location.line,
          lessThan(diagnostics[1].location.line),
        );
        expect(
          diagnostics[1].location.line,
          lessThan(diagnostics[2].location.line),
        );
      },
    );

    test(
      'correction text is populated and references the declaration name',
      () async {
        final diagnostics = await runRule('class _Foo {}\nvoid main() {}\n');
        expect(diagnostics, hasLength(1));
        expect(diagnostics.single.correction, 'Remove "_Foo" or reference it.');
      },
    );

    test('does not flag extension declarations', () async {
      final diagnostics = await runRule(
        'extension _Ext on int { int get doubled => this * 2; }\n'
        'void main() {}\n',
      );
      expect(diagnostics, isEmpty);
    });

    test('does not flag class typedef declarations', () async {
      final diagnostics = await runRule('''
class A {}
mixin B {}
class _Foo = A with B;
void main() {}
''');
      expect(diagnostics, isEmpty);
    });

    // === Dart 3 pattern-aware references (S3) ===

    test('counts a Dart 3 object pattern as a use', () async {
      final diagnostics = await runRule('''
class _Foo {}
bool isFoo(Object o) => switch (o) {
  _Foo() => true,
  _ => false,
};
void main() { isFoo(0); }
''');
      expect(diagnostics, isEmpty);
    });

    test('counts an object pattern with named fields as a use', () async {
      final diagnostics = await runRule('''
class _Foo {
  final int x;
  const _Foo(this.x);
}
int describe(Object o) => switch (o) {
  _Foo(x: final v) => v,
  _ => -1,
};
void main() { describe(0); }
''');
      expect(diagnostics, isEmpty);
    });

    test(
      'counts a constant pattern referencing a private class as a use',
      () async {
        final diagnostics = await runRule('''
class _Foo {
  static const _Foo instance = _Foo._();
  const _Foo._();
}
bool matchSentinel(Object o) => switch (o) {
  _Foo.instance => true,
  _ => false,
};
void main() { matchSentinel(0); }
''');
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'counts a record pattern containing an object pattern as a use',
      () async {
        final diagnostics = await runRule('''
class _Foo {}
bool match(Object o) => switch (o) {
  (_Foo(), int _) => true,
  _ => false,
};
void main() { match((0, 1)); }
''');
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'counts a record type annotation containing a private class as a use',
      () async {
        final diagnostics = await runRule('''
class _Foo {}
void accept((_Foo, int) pair) {}
void main() {}
''');
        expect(diagnostics, isEmpty);
      },
    );

    // === visitNamedType already covers the following positions — pin
    // the behaviour with tests so the coverage cannot regress silently.

    test(
      'counts a sealed class as used when matched via its subtype',
      () async {
        final diagnostics = await runRule('''
sealed class _Parent {}
class _ChildA extends _Parent {}
class _ChildB extends _Parent {}
String describe(Object o) => switch (o) {
  _ChildA() => 'a',
  _ChildB() => 'b',
  _ => 'other',
};
void main() { describe(0); }
''');
        expect(diagnostics, isEmpty);
      },
    );

    test('counts base/interface/final class modifiers via NamedType', () async {
      final diagnostics = await runRule('''
base class _Base {}
interface class _Iface {}
final class _Final {}
class _BaseUser extends _Base {}
class _IfaceUser implements _Iface {}
class _FinalUser { _Final? value; }
void main() {
  _BaseUser();
  _IfaceUser();
  _FinalUser();
}
''');
      expect(diagnostics, isEmpty);
    });

    test('counts a mixin used in an `on` clause as a use', () async {
      final diagnostics = await runRule('''
class _Base {}
mixin _Mix on _Base {}
class C extends _Base with _Mix {}
void main() { C(); }
''');
      expect(diagnostics, isEmpty);
    });

    test('counts a class used as a generic type argument as a use', () async {
      final diagnostics = await runRule('''
class _Foo {}
final List<_Foo> items = <_Foo>[];
void main() { items.length; }
''');
      expect(diagnostics, isEmpty);
    });

    // === dart:mirrors exemption ===

    test('does not flag any candidate when dart:mirrors is imported', () async {
      final diagnostics = await runRule('''
import 'dart:mirrors';
class _Foo {}
mixin _Bar {}
enum _Baz { a, b }
extension type _Qux(int v) {}
void main() { reflect(0); }
''');
      expect(diagnostics, isEmpty);
    });

    test(
      'still flags unused private declarations when dart:mirrors is not imported',
      () async {
        final diagnostics = await runRule('''
import 'dart:async';
class _Foo {}
void main() { Future<void>.value(); }
''');
        expect(diagnostics, hasLength(1));
        expect(diagnostics.single.message, contains('_Foo'));
      },
    );

    // Regression test for the `UnsupportedError: Requires
    // useDeclaringConstructorsAst = true` crash when reading
    // `ClassDeclaration.namePart` / `EnumDeclaration.namePart` on analyzer
    // 9.x/10.x with the experimental flag off. Analysis must complete
    // without throwing and must only report the private declarations.
    test(
      'does not throw on mixed public/private class and enum declarations',
      () async {
        const source = '''
class PublicClass {}
class _PrivateClass {}
enum PublicEnum { a, b }
enum _PrivateEnum { a, b }
void main() {}
''';
        await expectLater(runRule(source), completes);
        final diagnostics = await runRule(source);
        expect(diagnostics, hasLength(2));
        final messages = diagnostics.map((d) => d.message).toList();
        expect(messages, anyElement(contains('_PrivateClass')));
        expect(messages, anyElement(contains('_PrivateEnum')));
        for (final message in messages) {
          expect(message, isNot(contains('PublicClass')));
          expect(message, isNot(contains('PublicEnum')));
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
