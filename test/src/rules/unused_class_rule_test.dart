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
