/// Severity of a [Diagnostic] emitted by an `AnalyzerRule`.
///
/// The enum values are declared in ascending order of importance, so the
/// natural [Enum.index] comparison reflects severity ordering:
/// `Severity.info < Severity.warning < Severity.error`.
///
/// Consumers that need to gate on severity (for example, the CLI uses a
/// non-zero exit code when any diagnostic has [Severity.error]) should rely on
/// this ordering rather than string matching.
enum Severity {
  /// Informational message; not a problem, but worth surfacing.
  info,

  /// Likely problem that does not prevent the program from running.
  warning,

  /// Definite problem; causes the CLI to exit with a non-zero status.
  error,
}
