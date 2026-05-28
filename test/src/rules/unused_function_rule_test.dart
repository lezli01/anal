import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:anal/src/severity.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_rule_test_',
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

    test('reports unused top-level private function', () async {
      const source = 'void _foo() {}\nvoid main() {}\n';
      final diagnostics = await runRule(source);

      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_function');
      expect(diagnostic.severity, Severity.warning);
      expect(diagnostic.message, contains('_foo'));
      expect(diagnostic.message, contains('top-level'));
      expect(diagnostic.location.offset, source.indexOf('_foo'));
      expect(diagnostic.location.length, '_foo'.length);
      expect(diagnostic.location.line, 1);
      expect(diagnostic.location.column, source.indexOf('_foo') + 1);
    });

    test('does not report a used top-level private function', () async {
      final diagnostics = await runRule(
        'void _foo() {}\nvoid main() { _foo(); }\n',
      );
      expect(diagnostics, isEmpty);
    });

    test('counts tear-offs as a use', () async {
      final diagnostics = await runRule(
        'void _foo() {}\nfinal f = _foo;\nvoid main() { f(); }\n',
      );
      expect(diagnostics, isEmpty);
    });

    test('does not flag public top-level functions', () async {
      final diagnostics = await runRule('void foo() {}\nvoid main() {}\n');
      expect(diagnostics, isEmpty);
    });

    test('does not flag the library entry point main', () async {
      final diagnostics = await runRule('void main() {}\n');
      expect(diagnostics, isEmpty);
    });

    test('skips files in libraries that have parts', () async {
      File(
        p.join(tempDir.path, 'fixture_part.dart'),
      ).writeAsStringSync("part of 'fixture.dart';\n");
      final diagnostics = await runRule(
        "part 'fixture_part.dart';\nvoid _foo() {}\nvoid main() {}\n",
      );
      expect(diagnostics, isEmpty);
    });

    test('reports unused local function', () async {
      final diagnostics = await runRule('void main() {\n  void bar() {}\n}\n');
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_function');
      expect(diagnostic.message, contains('bar'));
      expect(diagnostic.message, contains('local'));
    });

    test('does not report used local function', () async {
      final diagnostics = await runRule(
        'void main() {\n  void bar() {}\n  bar();\n}\n',
      );
      expect(diagnostics, isEmpty);
    });

    test(
      'reports multiple unused functions sorted by line and column',
      () async {
        final diagnostics = await runRule(
          'void _foo() {}\nvoid _bar() {}\nvoid main() {}\n',
        );
        expect(diagnostics, hasLength(2));
        expect(diagnostics[0].message, contains('_foo'));
        expect(diagnostics[1].message, contains('_bar'));
        expect(
          diagnostics[0].location.line,
          lessThan(diagnostics[1].location.line),
        );
      },
    );

    test('skips functions annotated with @pragma(vm:entry-point)', () async {
      final diagnostics = await runRule(
        "@pragma('vm:entry-point')\nvoid _foo() {}\nvoid main() {}\n",
      );
      expect(diagnostics, isEmpty);
    });

    test('skips external top-level functions', () async {
      final diagnostics = await runRule(
        'external void _foo();\nvoid main() {}\n',
      );
      expect(diagnostics, isEmpty);
    });

    test('reports unused methods, getters, setters, and operators', () async {
      final diagnostics = await runRule('''
class C {
  void _method() {}
  static void _staticMethod() {}
  int get _value => 1;
  set _value(int v) {}
  C operator +(C other) => this;
}
void main() {
  C();
}
''');
      expect(diagnostics, hasLength(5));
      expect(diagnostics[0].message, contains('method "_method"'));
      expect(diagnostics[1].message, contains('static method "_staticMethod"'));
      expect(diagnostics[2].message, contains('getter "_value"'));
      expect(diagnostics[3].message, contains('setter "_value"'));
      expect(diagnostics[4].message, contains('operator "+"'));
    });

    test(
      'correction text is populated and references the declaration name',
      () async {
        final diagnostics = await runRule('void _foo() {}\nvoid main() {}\n');
        expect(diagnostics, hasLength(1));
        expect(diagnostics.single.correction, 'Remove "_foo" or reference it.');
      },
    );

    test(
      'object-pattern destructuring counts as a use of the getter',
      () async {
        final diagnostics = await runRule('''
class C {
  int get value => 1;
}
void main() {
  final C(:value) = C();
  // ignore: unused_local_variable
  final v = value;
}
''');
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'record literal + record-pattern destructuring counts as a use of the getter',
      () async {
        final diagnostics = await runRule('''
class C {
  int get value => 1;
}
void main() {
  final c = C();
  final record = (c.value,);
  final (v,) = record;
  // ignore: unused_local_variable
  final read = v;
}
''');
        expect(diagnostics, isEmpty);
      },
    );

    test('declared variable patterns descend into type annotations', () async {
      final diagnostics = await runRule('''
class _Box {
  const _Box();
}
void main() {
  Object o = const _Box();
  switch (o) {
    case _Box _:
      break;
    default:
      break;
  }
}
''');
      expect(diagnostics, isEmpty);
    });

    test('constant patterns descend into the wrapped expression', () async {
      final diagnostics = await runRule('''
class C {
  static const int marker = 1;
}
void main() {
  Object o = 1;
  switch (o) {
    case C.marker:
      break;
    default:
      break;
  }
}
''');
      expect(diagnostics, isEmpty);
    });

    test(
      'cascade method calls count as a use of the cascaded method',
      () async {
        final diagnostics = await runRule('''
class C {
  void cascaded() {}
}
void main() {
  C()..cascaded();
}
''');
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'callable-object `instance()` invocation counts as a use of `call`',
      () async {
        final diagnostics = await runRule('''
class C {
  void call() {}
}
void main() {
  final c = C();
  c();
}
''');
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'record literal field expressions descend into the recursive visitor',
      () async {
        final diagnostics = await runRule('''
class C {
  int produce() => 1;
}
void main() {
  final c = C();
  // ignore: unused_local_variable
  final record = (c.produce(),);
}
''');
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'classes that declare noSuchMethod exempt every member candidate',
      () async {
        final diagnostics = await runRule('''
class C {
  C();
  void wouldBeFlagged() {}
  int get wouldBeFlaggedGetter => 0;
  set wouldBeFlaggedSetter(int v) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
void main() {
  C();
}
''');
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'analyzed libraries that import dart:mirrors exempt every member candidate',
      () async {
        final diagnostics = await runRule('''
// ignore_for_file: unused_import, depend_on_referenced_packages
import 'dart:mirrors';

class C {
  C();
  void wouldBeFlagged() {}
  int get wouldBeFlaggedGetter => 0;
  set wouldBeFlaggedSetter(int v) {}
}
void main() {
  C();
}
''');
        expect(diagnostics, isEmpty);
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
