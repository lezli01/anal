import 'package:analyzer/dart/analysis/results.dart';

/// Carrier passed into every `AnalyzerRule.analyze` invocation.
///
/// An [AnalysisContext] bundles the resolved view of a single Dart source
/// file with its absolute path. The frame constructs one of these per file
/// and hands the same instance to each enabled rule.
///
/// Instances are immutable value carriers. There are intentionally no
/// mutable collectors, callbacks, or visitor hooks: rules surface their
/// findings exclusively through the return value of `AnalyzerRule.analyze`.
class AnalysisContext {
  /// Resolved compilation unit for the file under analysis.
  ///
  /// Exposes `unit.unit` (the `CompilationUnit` AST) and
  /// `unit.libraryElement` for symbol-level reasoning. Resolution means
  /// rules can inspect element references across the file, not just the
  /// raw syntax tree.
  final ResolvedUnitResult unit;

  /// Absolute, normalized path to the file under analysis.
  ///
  /// Always equal to `unit.path`; provided as a convenience so rules do
  /// not need to reach through [unit] for the common case of reporting a
  /// diagnostic location.
  final String filePath;

  /// Creates an [AnalysisContext] for a single resolved Dart file.
  const AnalysisContext({required this.unit, required this.filePath});
}
