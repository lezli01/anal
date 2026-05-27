/// Immutable configuration for a single analysis run.
///
/// [AnalOptions] describes which paths the runner should inspect and which
/// rules should be applied. Instances are deeply immutable value objects and
/// are safe to share across runs.
class AnalOptions {
  /// File-system paths, directories, or glob patterns to analyze.
  ///
  /// Stored as raw strings; glob resolution is performed later by the
  /// runner.
  final List<String> includePaths;

  /// Glob patterns to skip during analysis.
  ///
  /// Applied after [includePaths] has been expanded by the runner.
  final List<String> excludePaths;

  /// Identifiers of the rules that should be enabled for this run.
  ///
  /// An empty set means **all registered rules are enabled** — it is the
  /// default opt-in-everything behavior, not an opt-out-of-everything one.
  final Set<String> enabledRuleIds;

  /// Creates an [AnalOptions] with explicit values for every field.
  const AnalOptions({
    required this.includePaths,
    required this.excludePaths,
    required this.enabledRuleIds,
  });

  /// Creates an [AnalOptions] with sensible defaults for a typical Dart or
  /// Flutter package.
  ///
  /// Analyzes `lib/`, `bin/`, and `test/`, excludes nothing, and enables
  /// every registered rule (via an empty [enabledRuleIds]).
  const AnalOptions.defaults()
    : includePaths = const ['lib/', 'bin/', 'test/'],
      excludePaths = const [],
      enabledRuleIds = const <String>{};

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AnalOptions) return false;
    return _orderedEquals(includePaths, other.includePaths) &&
        _orderedEquals(excludePaths, other.excludePaths) &&
        _unorderedEquals(enabledRuleIds, other.enabledRuleIds);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(includePaths),
    Object.hashAll(excludePaths),
    Object.hashAllUnordered(enabledRuleIds),
  );

  @override
  String toString() =>
      'AnalOptions(includePaths: $includePaths, '
      'excludePaths: $excludePaths, '
      'enabledRuleIds: $enabledRuleIds)';
}

bool _orderedEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _unorderedEquals(Set<String> a, Set<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  return a.containsAll(b);
}
