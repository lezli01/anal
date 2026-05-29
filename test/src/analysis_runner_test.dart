import 'dart:io';

import 'package:anal/src/anal_options.dart';
import 'package:anal/src/analysis_context.dart';
import 'package:anal/src/analysis_runner.dart';
import 'package:anal/src/analyzer_rule.dart';
import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/multi_file_analyzer_rule.dart';
import 'package:anal/src/rule_registry.dart';
import 'package:anal/src/rules/unused_class_rule.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:anal/src/rules/unused_source_file_rule.dart';
import 'package:anal/src/severity.dart';
import 'package:anal/src/source_location.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _AlwaysFiresRule implements AnalyzerRule {
  @override
  String get id => 'always_fires';

  @override
  String get description => 'Always reports exactly one diagnostic per file.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(AnalysisContext context) {
    return <Diagnostic>[
      Diagnostic(
        ruleId: id,
        message: 'Saw file ${context.filePath}.',
        severity: defaultSeverity,
        location: SourceLocation(
          filePath: context.filePath,
          offset: 0,
          length: 0,
          line: 1,
          column: 1,
        ),
      ),
    ];
  }
}

class _OrderTrackingRule implements AnalyzerRule {
  _OrderTrackingRule(this.callLog);

  final List<String> callLog;

  @override
  String get id => 'order_tracking';

  @override
  String get description => 'Records when single-file analyze is invoked.';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  Iterable<Diagnostic> analyze(AnalysisContext context) {
    callLog.add('single:${context.filePath}');
    return const <Diagnostic>[];
  }
}

class _CapturingMultiFileRule implements MultiFileAnalyzerRule {
  _CapturingMultiFileRule({this.callLog});

  final List<String>? callLog;

  MultiFileAnalysisContext? lastContext;
  int callCount = 0;

  @override
  String get id => 'capturing_multi';

  @override
  String get description => 'Records the context it received.';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) {
    callCount += 1;
    lastContext = context;
    callLog?.add('multi:${context.analyzedFilePaths.length}');
    return const <Diagnostic>[];
  }
}

class _ThrowingMultiFileRule implements MultiFileAnalyzerRule {
  @override
  String get id => 'throwing_multi';

  @override
  String get description => 'Always throws when analyze is called.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) {
    throw StateError('boom');
  }
}

void main() {
  group('AnalysisRunner', () {
    late Directory tempDir;
    late String fixturePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anal_runner_test_');
      final fixture = File(p.join(tempDir.path, 'fixture.dart'));
      fixture.writeAsStringSync('void main() {}\n');
      fixturePath = p.normalize(p.absolute(fixture.path));
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('dispatches each registered rule once per resolved file', () async {
      final registry = RuleRegistry()..register(_AlwaysFiresRule());
      final runner = AnalysisRunner(
        registry: registry,
        options: AnalOptions(
          includePaths: [tempDir.path],
          excludePaths: const [],
          enabledRuleIds: const <String>{},
        ),
      );

      final diagnostics = await runner.run();

      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'always_fires');
      expect(diagnostic.location, isNotNull);
      expect(diagnostic.location.filePath, fixturePath);
    });
  });

  group('AnalysisRunner exclude matching', () {
    late Directory tempDir;
    late String savedCwd;

    setUp(() {
      savedCwd = Directory.current.path;
      tempDir = Directory.systemTemp.createTempSync('anal_runner_exclude_');
      Directory.current = tempDir.path;
    });

    tearDown(() {
      Directory.current = savedCwd;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    File writeFile(
      String relativePath, [
      String contents = 'void main() {}\n',
    ]) {
      final segments = p.split(relativePath);
      final file = File(p.joinAll([tempDir.path, ...segments]));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
      return file;
    }

    Future<Set<String>> analyze(List<String> excludePaths) async {
      final registry = RuleRegistry()..register(_AlwaysFiresRule());
      final runner = AnalysisRunner(
        registry: registry,
        options: AnalOptions(
          includePaths: [tempDir.path],
          excludePaths: excludePaths,
          enabledRuleIds: const <String>{},
        ),
      );
      final diagnostics = await runner.run();
      return {for (final d in diagnostics) p.normalize(d.location.filePath)};
    }

    test(
      'basename pattern *.g.dart excludes generated file in nested dir',
      () async {
        final keep = writeFile('keep.dart');
        writeFile(p.join('nested', 'foo.g.dart'));

        final analyzed = await analyze(const ['*.g.dart']);

        expect(analyzed, {p.normalize(p.absolute(keep.path))});
      },
    );

    test('**/*.freezed.dart excludes a deep freezed file', () async {
      final keep = writeFile('keep.dart');
      writeFile(p.join('a', 'b', 'c', 'thing.freezed.dart'));

      final analyzed = await analyze(const ['**/*.freezed.dart']);

      expect(analyzed, {p.normalize(p.absolute(keep.path))});
    });

    test('explicit absolute-path exclude pattern still works', () async {
      final keep = writeFile('keep.dart');
      final drop = writeFile('drop.dart');
      final dropAbs = p.normalize(p.absolute(drop.path));

      final analyzed = await analyze([dropAbs]);

      expect(analyzed, {p.normalize(p.absolute(keep.path))});
    });

    test(
      'AnalOptions.defaultExcludePaths excludes generated files and tool/build caches but keeps keep.dart',
      () async {
        final keep = writeFile('keep.dart');
        writeFile('foo.g.dart');
        writeFile('bar.freezed.dart');
        writeFile(p.join('nested', 'baz.g.dart'));
        writeFile(
          p.join('.dart_tool', 'flutter_build', 'dart_plugin_registrant.dart'),
        );
        writeFile(
          p.join('.dart_tool', 'dartpad', 'web_plugin_registrant.dart'),
        );
        writeFile(p.join('build', 'generated', 'thing.dart'));
        writeFile(p.join('nested', 'build', 'deep.dart'));

        final analyzed = await analyze(AnalOptions.defaultExcludePaths);

        expect(analyzed, {p.normalize(p.absolute(keep.path))});
      },
    );

    test('custom pattern *.bak.dart excludes basename matches', () async {
      final keep = writeFile('keep.dart');
      writeFile('scratch.bak.dart');
      writeFile(p.join('nested', 'other.bak.dart'));

      final analyzed = await analyze(const ['*.bak.dart']);

      expect(analyzed, {p.normalize(p.absolute(keep.path))});
    });

    test('empty excludePaths excludes nothing', () async {
      final keep = writeFile('keep.dart');
      final gen = writeFile('foo.g.dart');
      final freezed = writeFile('bar.freezed.dart');

      final analyzed = await analyze(const <String>[]);

      expect(analyzed, {
        p.normalize(p.absolute(keep.path)),
        p.normalize(p.absolute(gen.path)),
        p.normalize(p.absolute(freezed.path)),
      });
    });
  });

  group('AnalysisRunner multi-file dispatch', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anal_runner_multi_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    String writeFile(String name, [String contents = 'void main() {}\n']) {
      final file = File(p.join(tempDir.path, name));
      file.writeAsStringSync(contents);
      return p.normalize(p.absolute(file.path));
    }

    test('multi-file rule sees every analyzed file', () async {
      final a = writeFile('a.dart');
      final b = writeFile('b.dart');
      final c = writeFile('c.dart');
      final multi = _CapturingMultiFileRule();
      final registry = RuleRegistry()..registerMultiFile(multi);
      final runner = AnalysisRunner(
        registry: registry,
        options: AnalOptions(
          includePaths: [tempDir.path],
          excludePaths: const [],
          enabledRuleIds: const <String>{},
        ),
      );

      final diagnostics = await runner.run();

      expect(diagnostics, isEmpty);
      expect(multi.callCount, 1);
      expect(multi.lastContext, isNotNull);
      expect(multi.lastContext!.analyzedFilePaths, <String>{a, b, c});
      expect(
        multi.lastContext!.units.map((unit) => unit.path).toSet(),
        <String>{a, b, c},
      );
    });

    test('multi-file rules run after single-file ones', () async {
      final a = writeFile('a.dart');
      final b = writeFile('b.dart');
      final callLog = <String>[];
      final registry = RuleRegistry()
        ..register(_OrderTrackingRule(callLog))
        ..registerMultiFile(_CapturingMultiFileRule(callLog: callLog));
      final runner = AnalysisRunner(
        registry: registry,
        options: AnalOptions(
          includePaths: [tempDir.path],
          excludePaths: const [],
          enabledRuleIds: const <String>{},
        ),
      );

      await runner.run();

      expect(callLog, <String>['single:$a', 'single:$b', 'multi:2']);
    });

    test('empty file list still skips multi-file dispatch cleanly', () async {
      final multi = _CapturingMultiFileRule();
      final registry = RuleRegistry()..registerMultiFile(multi);
      final runner = AnalysisRunner(
        registry: registry,
        options: AnalOptions(
          includePaths: [tempDir.path],
          excludePaths: const [],
          enabledRuleIds: const <String>{},
        ),
      );

      final diagnostics = await runner.run();

      expect(diagnostics, isEmpty);
      expect(multi.callCount, 0);
      expect(multi.lastContext, isNull);
    });

    test(
      'throwing multi-file rule produces an _internal error diagnostic',
      () async {
        writeFile('a.dart');
        final registry = RuleRegistry()
          ..registerMultiFile(_ThrowingMultiFileRule());
        final runner = AnalysisRunner(
          registry: registry,
          options: AnalOptions(
            includePaths: [tempDir.path],
            excludePaths: const [],
            enabledRuleIds: const <String>{},
          ),
        );

        final diagnostics = await runner.run();

        expect(diagnostics, hasLength(1));
        final diagnostic = diagnostics.single;
        expect(diagnostic.ruleId, '_internal');
        expect(diagnostic.severity, Severity.error);
        expect(diagnostic.message, contains('throwing_multi'));
        expect(diagnostic.message, contains('boom'));
      },
    );
  });

  group('AnalysisRunner excluded-as-reference dispatch', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'anal_runner_excluded_ref_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    String writeFile(String name, [String contents = 'void main() {}\n']) {
      final file = File(p.join(tempDir.path, name));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
      return p.normalize(p.absolute(file.path));
    }

    test('excluded files do not receive single-file rule dispatch but are '
        'still visible in the multi-file context', () async {
      final keep = writeFile('keep.dart');
      final excluded = writeFile('thing.g.dart');
      final callLog = <String>[];
      final multi = _CapturingMultiFileRule();
      final registry = RuleRegistry()
        ..register(_OrderTrackingRule(callLog))
        ..registerMultiFile(multi);
      final runner = AnalysisRunner(
        registry: registry,
        options: AnalOptions(
          includePaths: [tempDir.path],
          excludePaths: const ['*.g.dart'],
          enabledRuleIds: const <String>{},
        ),
      );

      await runner.run();

      expect(callLog, <String>['single:$keep']);
      expect(multi.callCount, 1);
      expect(multi.lastContext, isNotNull);
      expect(
        multi.lastContext!.units.map((unit) => unit.path).toSet(),
        <String>{keep, excluded},
      );
      expect(multi.lastContext!.analyzedFilePaths, <String>{keep, excluded});
      expect(multi.lastContext!.reportableFilePaths, <String>{keep});
    });

    test(
      'with no excludes reportableFilePaths equals analyzedFilePaths',
      () async {
        final a = writeFile('a.dart');
        final b = writeFile('b.dart');
        final multi = _CapturingMultiFileRule();
        final registry = RuleRegistry()..registerMultiFile(multi);
        final runner = AnalysisRunner(
          registry: registry,
          options: AnalOptions(
            includePaths: [tempDir.path],
            excludePaths: const [],
            enabledRuleIds: const <String>{},
          ),
        );

        await runner.run();

        expect(multi.callCount, 1);
        expect(multi.lastContext, isNotNull);
        expect(multi.lastContext!.analyzedFilePaths, <String>{a, b});
        expect(multi.lastContext!.reportableFilePaths, <String>{a, b});
        expect(
          multi.lastContext!.reportableFilePaths,
          multi.lastContext!.analyzedFilePaths,
        );
      },
    );
  });

  group('AnalysisRunner default excludes regression', () {
    late Directory tempDir;
    late String savedCwd;

    setUp(() {
      savedCwd = Directory.current.path;
      tempDir = Directory.systemTemp.createTempSync(
        'anal_runner_defaults_regression_',
      );
      Directory.current = tempDir.path;
    });

    tearDown(() {
      Directory.current = savedCwd;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    void writeFile(String relativePath, [String contents = '']) {
      final segments = p.split(relativePath);
      final file = File(p.joinAll([tempDir.path, ...segments]));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
    }

    test(
      'momminess-shaped layout: lib/main.dart + .dart_tool/ registrant '
      'emits no unused_source_file diagnostic with default options',
      () async {
        writeFile(p.join('lib', 'main.dart'), 'void main() {}\n');
        writeFile(
          p.join('.dart_tool', 'flutter_build', 'dart_plugin_registrant.dart'),
          '// Generated by Flutter. Do not edit.\n'
          'void main() {}\n',
        );

        final registry = RuleRegistry()
          ..registerMultiFile(UnusedSourceFileRule());
        final runner = AnalysisRunner(
          registry: registry,
          options: AnalOptions(
            includePaths: [tempDir.path],
            excludePaths: AnalOptions.defaultExcludePaths,
            enabledRuleIds: const <String>{},
          ),
        );

        final diagnostics = await runner.run();

        expect(
          diagnostics.where((d) => d.ruleId == 'unused_source_file'),
          isEmpty,
        );
      },
    );
  });

  group('AnalysisRunner unused-rule nesting suppression', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('anal_runner_nesting_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    void writeFile(String relativePath, String contents) {
      final file = File(p.joinAll([tempDir.path, ...p.split(relativePath)]));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(contents);
    }

    String absPath(String relativePath) =>
        p.normalize(p.joinAll([tempDir.path, ...p.split(relativePath)]));

    RuleRegistry buildRegistry() => RuleRegistry()
      ..registerMultiFile(UnusedFunctionRule())
      ..register(UnusedClassRule())
      ..registerMultiFile(UnusedSourceFileRule());

    Future<List<Diagnostic>> run() async {
      final runner = AnalysisRunner(
        registry: buildRegistry(),
        options: AnalOptions(
          includePaths: [tempDir.path],
          excludePaths: const [],
          enabledRuleIds: const <String>{},
        ),
      );
      return runner.run();
    }

    test(
      'unused_source_file subsumes unused_class/unused_function inside a dead '
      'file, but reachable files are still flagged',
      () async {
        // `lib/app.dart` sits directly under lib/ (an entry point) and pulls
        // in `lib/src/used.dart`, keeping it reachable. `lib/src/orphan.dart`
        // is reached by nothing. Both the reachable and the dead file declare
        // an unreferenced private function and private class.
        writeFile(p.join('lib', 'app.dart'), '''
import 'src/used.dart';

void main() {
  alive();
}
''');
        writeFile(p.join('lib', 'src', 'used.dart'), '''
void alive() {}

void _aliveUnusedFn() {}

class _AliveUnusedClass {}
''');
        writeFile(p.join('lib', 'src', 'orphan.dart'), '''
void _deadFn() {}

class _DeadClass {}
''');

        final diagnostics = await run();

        expect(
          diagnostics.where((d) => d.ruleId == '_internal'),
          isEmpty,
          reason: diagnostics
              .where((d) => d.ruleId == '_internal')
              .map((d) => d.message)
              .toList()
              .toString(),
        );

        final orphan = absPath(p.join('lib', 'src', 'orphan.dart'));
        final used = absPath(p.join('lib', 'src', 'used.dart'));

        // The dead file is reported exactly once, at the file level.
        expect(
          diagnostics
              .where((d) => d.location.filePath == orphan)
              .map((d) => d.ruleId),
          ['unused_source_file'],
        );

        // The reachable file's unreferenced private declarations are still
        // flagged — the suppression is scoped to dead files only.
        final usedRuleIds = diagnostics
            .where((d) => d.location.filePath == used)
            .map((d) => d.ruleId)
            .toSet();
        expect(
          usedRuleIds,
          containsAll(<String>['unused_class', 'unused_function']),
        );
        expect(
          diagnostics.where((d) => d.ruleId == 'unused_source_file').length,
          1,
        );
      },
    );

    test(
      'disabling unused_source_file lets the per-declaration findings through',
      () async {
        // Same dead file, but with only unused_class + unused_function enabled
        // there is no file-level finding to subsume them, so they surface.
        writeFile(p.join('lib', 'app.dart'), 'void main() {}\n');
        writeFile(p.join('lib', 'src', 'orphan.dart'), '''
void _deadFn() {}

class _DeadClass {}
''');

        final runner = AnalysisRunner(
          registry: buildRegistry(),
          options: AnalOptions(
            includePaths: [tempDir.path],
            excludePaths: const [],
            enabledRuleIds: const <String>{'unused_class', 'unused_function'},
          ),
        );
        final diagnostics = await runner.run();

        final orphan = absPath(p.join('lib', 'src', 'orphan.dart'));
        final orphanRuleIds = diagnostics
            .where((d) => d.location.filePath == orphan)
            .map((d) => d.ruleId)
            .toSet();
        expect(orphanRuleIds, <String>{'unused_class', 'unused_function'});
        expect(
          diagnostics.where((d) => d.ruleId == 'unused_source_file'),
          isEmpty,
        );
      },
    );
  });
}
