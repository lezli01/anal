/// `anal` is a pluggable static analysis framework for Dart and Flutter
/// projects.
///
/// This library re-exports the package's public surface: the [AnalyzerRule]
/// extension point, the runner that drives it, the diagnostic value types,
/// and the configuration/reporting helpers. Implementation details live
/// under `lib/src/` and are not part of the stable surface.
library;

export 'src/anal_options.dart';
export 'src/analysis_context.dart';
export 'src/analysis_runner.dart';
export 'src/analyzer_rule.dart';
export 'src/diagnostic.dart';
export 'src/reporter.dart';
export 'src/rule_registry.dart';
export 'src/rules/unused_function_rule.dart';
export 'src/rules/unused_class_rule.dart';
export 'src/severity.dart';
export 'src/source_location.dart';
