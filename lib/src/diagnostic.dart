import 'severity.dart';
import 'source_location.dart';

/// A finding produced by an `AnalyzerRule` while analyzing a single file.
///
/// A [Diagnostic] is an immutable value: rules construct one for each issue
/// they detect and return them from `AnalyzerRule.analyze`. The runner then
/// hands the accumulated list to a `Reporter` for presentation.
///
/// Instances compare structurally on every field, including the optional
/// [correction] hint.
class Diagnostic {
  /// Identifier of the rule that produced this diagnostic.
  ///
  /// Matches `AnalyzerRule.id` and follows the same `lowercase_with_underscores`
  /// convention.
  final String ruleId;

  /// Human-readable, single-line description of the problem.
  final String message;

  /// Severity emitted for this finding.
  final Severity severity;

  /// Location in the source where the diagnostic applies.
  final SourceLocation location;

  /// Optional remediation hint shown alongside [message].
  ///
  /// `null` when the rule has no suggestion to offer.
  final String? correction;

  /// Creates a [Diagnostic].
  ///
  /// [ruleId], [message], [severity], and [location] are required. [correction]
  /// is optional and defaults to `null`.
  const Diagnostic({
    required this.ruleId,
    required this.message,
    required this.severity,
    required this.location,
    this.correction,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Diagnostic &&
        other.ruleId == ruleId &&
        other.message == message &&
        other.severity == severity &&
        other.location == location &&
        other.correction == correction;
  }

  @override
  int get hashCode =>
      Object.hash(ruleId, message, severity, location, correction);

  @override
  String toString() =>
      'Diagnostic($ruleId, $severity, $location, $message'
      '${correction == null ? '' : ', correction: $correction'})';
}
