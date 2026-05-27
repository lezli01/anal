import 'analyzer_rule.dart';
import 'multi_file_analyzer_rule.dart';

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
///
/// The registry also tracks [MultiFileAnalyzerRule] instances on a
/// parallel, independent path. Single-file and multi-file rules live in
/// separate namespaces: registering an id on one side does not block the
/// same id on the other.
class RuleRegistry {
  final List<AnalyzerRule> _rules = <AnalyzerRule>[];
  final Map<String, AnalyzerRule> _byId = <String, AnalyzerRule>{};

  final List<MultiFileAnalyzerRule> _multiFileRules = <MultiFileAnalyzerRule>[];
  final Map<String, MultiFileAnalyzerRule> _byMultiFileId =
      <String, MultiFileAnalyzerRule>{};

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

  /// Registers [rule] with this registry's multi-file namespace.
  ///
  /// Throws a [StateError] if a multi-file rule with the same
  /// [MultiFileAnalyzerRule.id] has already been registered. Ids are
  /// the rule's public contract, so silently overwriting one would be a
  /// configuration bug.
  void registerMultiFile(MultiFileAnalyzerRule rule) {
    if (_byMultiFileId.containsKey(rule.id)) {
      throw StateError(
        'A multi-file rule with id "${rule.id}" is already registered.',
      );
    }
    _byMultiFileId[rule.id] = rule;
    _multiFileRules.add(rule);
  }

  /// All registered multi-file rules, in the order they were registered.
  Iterable<MultiFileAnalyzerRule> get multiFileRules => _multiFileRules;

  /// Looks up a registered multi-file rule by [id], or returns `null`
  /// when no multi-file rule with that id has been registered.
  MultiFileAnalyzerRule? byMultiFileId(String id) => _byMultiFileId[id];
}
