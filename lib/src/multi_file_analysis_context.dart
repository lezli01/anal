import 'package:analyzer/dart/analysis/results.dart';

/// Carrier passed into every `MultiFileAnalyzerRule.analyze` invocation.
///
/// A [MultiFileAnalysisContext] bundles the resolved view of every Dart
/// source file in the run with the absolute set of paths that were
/// analyzed. The frame constructs one of these per run and hands the same
/// instance to each enabled multi-file rule.
///
/// Instances are immutable value carriers. There are intentionally no
/// mutable collectors, callbacks, or visitor hooks: rules surface their
/// findings exclusively through the return value of
/// `MultiFileAnalyzerRule.analyze`.
class MultiFileAnalysisContext {
  /// Resolved compilation units for every Dart file under analysis.
  ///
  /// Each entry exposes `unit.unit` (the `CompilationUnit` AST) and
  /// `unit.libraryElement` for symbol-level reasoning. Resolution means
  /// rules can inspect element references across the whole set of files,
  /// not just the raw syntax trees.
  ///
  /// The list is unmodifiable; attempts to mutate it throw.
  final List<ResolvedUnitResult> units;

  /// Absolute, normalized paths of every file under analysis.
  ///
  /// Provided as a convenience so rules can test membership ("is this
  /// path part of the analyzed set?") in constant time without scanning
  /// [units]. Always equal to `{for (final u in units) u.path}`.
  ///
  /// The set is unmodifiable; attempts to mutate it throw.
  final Set<String> analyzedFilePaths;

  /// Creates a [MultiFileAnalysisContext] for a run.
  ///
  /// [units] and [analyzedFilePaths] are wrapped in unmodifiable views so
  /// rules cannot mutate the inputs the frame shares between them.
  MultiFileAnalysisContext({
    required List<ResolvedUnitResult> units,
    required Set<String> analyzedFilePaths,
  }) : units = List<ResolvedUnitResult>.unmodifiable(units),
       analyzedFilePaths = Set<String>.unmodifiable(analyzedFilePaths);
}
