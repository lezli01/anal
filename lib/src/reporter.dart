import 'dart:io';

import 'diagnostic.dart';

/// Presents a list of [Diagnostic]s to some sink (console, file, IDE, ...).
///
/// Implementations decide the wire format and destination. The runner calls
/// [report] exactly once with the full accumulated diagnostic list at the end
/// of an analysis run.
abstract class Reporter {
  /// Writes [diagnostics] to the implementation's destination.
  void report(List<Diagnostic> diagnostics);
}

/// A [Reporter] that writes diagnostics to an [IOSink], grouped by file.
///
/// Diagnostics are bucketed by `location.filePath` while preserving the order
/// in which each file first appears in the input, and within each file the
/// input order of diagnostics is kept verbatim (the reporter does not sort
/// by line, column, or severity). Each file path is emitted exactly once as
/// a header line, followed by one indented line per finding shaped as
/// `<line>:<column> • [<severity>] <ruleId>: <message>`, where `<severity>`
/// is the lowercase enum name (`info`, `warning`, `error`). When a finding
/// carries a non-null [Diagnostic.correction], the correction text is
/// written on a further-indented continuation line.
///
/// An empty diagnostic list produces no output. No ANSI colors are emitted
/// and no global `stdout` is referenced — output goes exclusively to the
/// [IOSink] passed to the constructor.
///
/// Example output:
///
/// ```
/// lib/src/foo.dart
///   3:7 • [warning] unused_function: Function "foo" is never used.
///     Remove it or use it.
///   8:1 • [info] unused_function: Function "bar" is never used.
/// lib/src/baz.dart
///   1:1 • [error] _internal: Failed to parse.
/// ```
class ConsoleReporter implements Reporter {
  /// Sink that receives the grouped diagnostic report.
  final IOSink out;

  /// Creates a [ConsoleReporter] that writes to [out].
  ConsoleReporter({required this.out});

  @override
  void report(List<Diagnostic> diagnostics) {
    final byFile = <String, List<Diagnostic>>{};
    for (final d in diagnostics) {
      (byFile[d.location.filePath] ??= <Diagnostic>[]).add(d);
    }
    for (final entry in byFile.entries) {
      out.writeln(entry.key);
      for (final d in entry.value) {
        out.writeln(
          '  ${d.location.line}:${d.location.column}'
          ' • [${d.severity.name}] ${d.ruleId}: ${d.message}',
        );
        final correction = d.correction;
        if (correction != null) {
          out.writeln('    $correction');
        }
      }
    }
  }
}
