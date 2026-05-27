import 'analyzer_rule.dart';

/// In-memory collection of [AnalyzerRule] instances keyed by
/// `AnalyzerRule.id`.
///
/// A [RuleRegistry] is the assembly point the CLI (and any programmatic
/// consumer) uses to declare which rules participate in a run. It is a
/// plain, instance-scoped object — there is intentionally **no global
/// singleton**, so multiple runs in the same process do not leak state
/// into each other.
///
/// Rules are kept in **insertion order** so reports and trace output are
/// deterministic for a given registration script.
class RuleRegistry {
  final List<AnalyzerRule> _rules = <AnalyzerRule>[];
  final Map<String, AnalyzerRule> _byId = <String, AnalyzerRule>{};

  /// Creates an empty registry.
  RuleRegistry();

  /// Registers [rule] with this registry.
  ///
  /// Throws a [StateError] if a rule with the same
  /// [AnalyzerRule.id] has already been registered. Ids are the rule's
  /// public contract, so silently overwriting one would be a
  /// configuration bug.
  void register(AnalyzerRule rule) {
    if (_byId.containsKey(rule.id)) {
      throw StateError('A rule with id "${rule.id}" is already registered.');
    }
    _byId[rule.id] = rule;
    _rules.add(rule);
  }

  /// All registered rules, in the order they were registered.
  Iterable<AnalyzerRule> get rules => _rules;

  /// Looks up a registered rule by [id], or returns `null` when no rule
  /// with that id has been registered.
  AnalyzerRule? byId(String id) => _byId[id];
}
