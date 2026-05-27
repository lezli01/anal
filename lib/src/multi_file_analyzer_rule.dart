import 'diagnostic.dart';
import 'multi_file_analysis_context.dart';
import 'severity.dart';

/// Extension point implemented by every cross-file analyzer rule.
///
/// A rule is a small, stateless object that inspects the resolved set of
/// Dart files in a run (delivered via [MultiFileAnalysisContext]) and
/// emits zero or more [Diagnostic]s describing problems it found across
/// that set.
///
/// ### Identifier convention
///
/// [id] is a stable, lowercase_with_underscores string (for example,
/// `unused_source_file` or `cyclic_imports`). The id appears in
/// configuration, console reports, and on every [Diagnostic] this rule
/// produces, so it must be unique within a [`RuleRegistry`]'s multi-file
/// namespace and should not change once published.
///
/// ### Purity contract
///
/// Implementations of [analyze] **must be pure**:
///
/// * no I/O — do not read files, hit the network, or touch the
///   filesystem;
/// * no caching across calls — every invocation must derive its result
///   solely from the supplied [MultiFileAnalysisContext];
/// * no global or shared mutable state.
///
/// The frame may dispatch rules in any order and may, in future, run them
/// concurrently. Side effects break those guarantees.
///
/// ### Dispatch model
///
/// Rules are dispatched **once per run**, with every analyzed file made
/// available at once. Single-file analyses (for example, "this local
/// variable is shadowed") are explicitly **out of scope** for this
/// extension point and should be implemented as an `AnalyzerRule`
/// instead.
abstract class MultiFileAnalyzerRule {
  /// Stable identifier used in configuration and reports.
  ///
  /// Must be `lowercase_with_underscores` and unique within a
  /// `RuleRegistry`'s multi-file namespace. Treated as part of the
  /// rule's public contract — do not rename after publishing.
  String get id;

  /// One-line, human-readable description shown in `--help` and reports.
  String get description;

  /// Severity emitted for diagnostics produced by this rule.
  ///
  /// Consumers may, in a future version, override this per-rule via
  /// configuration; rules themselves should not branch on the override
  /// and should always emit this default.
  Severity get defaultSeverity;

  /// Inspects [context] and returns the diagnostics produced for the set
  /// of files it describes.
  ///
  /// Returns an empty iterable when the rule has nothing to report.
  /// Implementations must honor the purity and dispatch contracts
  /// documented on [MultiFileAnalyzerRule].
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context);
}
