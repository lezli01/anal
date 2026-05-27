import 'analysis_context.dart';
import 'diagnostic.dart';
import 'severity.dart';

/// Extension point implemented by every analyzer rule.
///
/// A rule is a small, stateless object that inspects a single resolved Dart
/// file (delivered via [AnalysisContext]) and emits zero or more
/// [Diagnostic]s describing problems it found.
///
/// ### Identifier convention
///
/// [id] is a stable, lowercase_with_underscores string (for example,
/// `unused_function` or `prefer_const_constructor`). The id appears in
/// configuration, console reports, and on every [Diagnostic] this rule
/// produces, so it must be unique within a [`RuleRegistry`] and should not
/// change once published.
///
/// ### Purity contract
///
/// Implementations of [analyze] **must be pure**:
///
/// * no I/O — do not read files, hit the network, or touch the
///   filesystem;
/// * no caching across calls — every invocation must derive its result
///   solely from the supplied [AnalysisContext];
/// * no global or shared mutable state.
///
/// The frame may dispatch rules in any order and may, in future, run them
/// concurrently. Side effects break those guarantees.
///
/// ### Dispatch model
///
/// Rules are dispatched **once per file**. Cross-file analyses (for
/// example, "this function is unused across the whole package") are
/// explicitly **out of scope for the frame** and should not be attempted
/// by implementing [AnalyzerRule]; a future, separate extension point
/// will cover that case.
abstract class AnalyzerRule {
  /// Stable identifier used in configuration and reports.
  ///
  /// Must be `lowercase_with_underscores` and unique within a
  /// `RuleRegistry`. Treated as part of the rule's public contract — do
  /// not rename after publishing.
  String get id;

  /// One-line, human-readable description shown in `--help` and reports.
  String get description;

  /// Severity emitted for diagnostics produced by this rule.
  ///
  /// Consumers may, in a future version, override this per-rule via
  /// configuration; rules themselves should not branch on the override
  /// and should always emit this default.
  Severity get defaultSeverity;

  /// Inspects [context] and returns the diagnostics produced for the
  /// single file it describes.
  ///
  /// Returns an empty iterable when the rule has nothing to report.
  /// Implementations must honor the purity and dispatch contracts
  /// documented on [AnalyzerRule].
  Iterable<Diagnostic> analyze(AnalysisContext context);
}
