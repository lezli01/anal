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
}
