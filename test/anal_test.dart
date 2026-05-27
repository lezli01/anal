import 'package:anal/anal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'public surface is exported and constructible from package:anal/anal.dart',
    () {
      final registry = RuleRegistry();
      const options = AnalOptions.defaults();
      final runner = AnalysisRunner(registry: registry, options: options);

      expect(registry, isA<RuleRegistry>());
      expect(options, isA<AnalOptions>());
      expect(runner, isA<AnalysisRunner>());

      expect(Severity.error, isA<Severity>());

      const location = SourceLocation(
        filePath: '/tmp/x.dart',
        offset: 0,
        length: 1,
        line: 1,
        column: 1,
      );
      const diagnostic = Diagnostic(
        ruleId: 'r',
        message: 'm',
        severity: Severity.info,
        location: location,
      );
      expect(location, isA<SourceLocation>());
      expect(diagnostic, isA<Diagnostic>());

      expect(AnalyzerRule, AnalyzerRule);
    },
  );

  test('UnusedFunctionRule is exported with the expected id and severity', () {
    expect(const UnusedFunctionRule().id, 'unused_function');
    expect(const UnusedFunctionRule().defaultSeverity, Severity.warning);
  });
}
