import 'package:anal/src/analysis_context.dart';
import 'package:anal/src/analyzer_rule.dart';
import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/rule_registry.dart';
import 'package:anal/src/severity.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubRule implements AnalyzerRule {
  _StubRule(this.id);

  @override
  final String id;

  @override
  String get description => 'stub';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  Iterable<Diagnostic> analyze(AnalysisContext context) => const <Diagnostic>[];
}

void main() {
  group('RuleRegistry', () {
    test('register adds a rule that is then findable by id', () {
      final registry = RuleRegistry();
      final rule = _StubRule('alpha');

      registry.register(rule);

      expect(registry.byId('alpha'), same(rule));
    });

    test(
      'rules getter preserves insertion order across multiple registers',
      () {
        final registry = RuleRegistry();
        final a = _StubRule('alpha');
        final b = _StubRule('bravo');
        final c = _StubRule('charlie');

        registry.register(a);
        registry.register(b);
        registry.register(c);

        expect(registry.rules.toList(), <AnalyzerRule>[a, b, c]);
      },
    );

    test('registering a duplicate id throws StateError', () {
      final registry = RuleRegistry();
      registry.register(_StubRule('alpha'));

      expect(
        () => registry.register(_StubRule('alpha')),
        throwsA(isA<StateError>()),
      );
    });

    test('byId returns null for an unknown id', () {
      final registry = RuleRegistry();
      registry.register(_StubRule('alpha'));

      expect(registry.byId('unknown'), isNull);
    });
  });
}
