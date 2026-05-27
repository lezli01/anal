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

/// A [Reporter] that writes one human-readable line per diagnostic to an
/// [IOSink].
///
/// Each diagnostic is rendered as:
///
/// ```
/// <filePath>:<line>:<column> • [<severity>] <ruleId>: <message>
/// ```
///
/// where `<severity>` is the lowercase enum name (`info`, `warning`, `error`).
/// No ANSI colors are emitted and no global `stdout` is referenced — output
/// goes exclusively to the [IOSink] passed to the constructor.
class ConsoleReporter implements Reporter {
  /// Sink that receives one line per diagnostic.
  final IOSink out;

  /// Creates a [ConsoleReporter] that writes to [out].
  ConsoleReporter({required this.out});

  @override
  void report(List<Diagnostic> diagnostics) {
    for (final d in diagnostics) {
      out.writeln(
        '${d.location.filePath}:${d.location.line}:${d.location.column}'
        ' • [${d.severity.name}] ${d.ruleId}: ${d.message}',
      );
    }
  }
}
