import 'dart:io';

import 'package:anal/src/anal_options.dart';
import 'package:anal/src/analysis_context.dart';
import 'package:anal/src/analysis_runner.dart';
import 'package:anal/src/analyzer_rule.dart';
import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/rule_registry.dart';
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
      'AnalOptions.defaultExcludePaths excludes generated files but keeps keep.dart',
      () async {
        final keep = writeFile('keep.dart');
        writeFile('foo.g.dart');
        writeFile('bar.freezed.dart');
        writeFile(p.join('nested', 'baz.g.dart'));

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
}
