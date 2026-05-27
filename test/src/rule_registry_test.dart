import 'package:anal/src/analysis_context.dart';
import 'package:anal/src/analyzer_rule.dart';
import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/multi_file_analyzer_rule.dart';
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

class _StubMultiFileRule implements MultiFileAnalyzerRule {
  _StubMultiFileRule(this.id);

  @override
  final String id;

  @override
  String get description => 'stub';

  @override
  Severity get defaultSeverity => Severity.info;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) =>
      const <Diagnostic>[];
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

    test('registerMultiFile adds a rule that is then findable by id', () {
      final registry = RuleRegistry();
      final rule = _StubMultiFileRule('alpha');

      registry.registerMultiFile(rule);

      expect(registry.byMultiFileId('alpha'), same(rule));
    });

    test('multiFileRules getter preserves insertion order across multiple '
        'registers', () {
      final registry = RuleRegistry();
      final a = _StubMultiFileRule('alpha');
      final b = _StubMultiFileRule('bravo');
      final c = _StubMultiFileRule('charlie');

      registry.registerMultiFile(a);
      registry.registerMultiFile(b);
      registry.registerMultiFile(c);

      expect(registry.multiFileRules.toList(), <MultiFileAnalyzerRule>[
        a,
        b,
        c,
      ]);
    });

    test('registering a duplicate multi-file id throws StateError', () {
      final registry = RuleRegistry();
      registry.registerMultiFile(_StubMultiFileRule('alpha'));

      expect(
        () => registry.registerMultiFile(_StubMultiFileRule('alpha')),
        throwsA(isA<StateError>()),
      );
    });

    test('byMultiFileId returns null for an unknown id', () {
      final registry = RuleRegistry();
      registry.registerMultiFile(_StubMultiFileRule('alpha'));

      expect(registry.byMultiFileId('unknown'), isNull);
    });

    test('single-file and multi-file namespaces do not cross-talk', () {
      final registry = RuleRegistry();
      final single = _StubRule('alpha');
      final multi = _StubMultiFileRule('alpha');

      registry.register(single);
      registry.registerMultiFile(multi);

      expect(registry.byId('alpha'), same(single));
      expect(registry.byMultiFileId('alpha'), same(multi));
      expect(registry.rules.toList(), <AnalyzerRule>[single]);
      expect(registry.multiFileRules.toList(), <MultiFileAnalyzerRule>[multi]);
    });
  });
}
