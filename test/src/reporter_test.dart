import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/reporter.dart';
import 'package:anal/src/severity.dart';
import 'package:anal/src/source_location.dart';
import 'package:flutter_test/flutter_test.dart';

/// Drives [body] against a [ConsoleReporter] backed by an in-memory
/// [IOSink] and returns the decoded text written to that sink.
Future<String> _capture(void Function(ConsoleReporter reporter) body) async {
  final consumer = _MemoryConsumer();
  final sink = IOSink(consumer);
  body(ConsoleReporter(out: sink));
  await sink.close();
  return utf8.decode(consumer.bytes);
}

class _MemoryConsumer implements StreamConsumer<List<int>> {
  final List<int> bytes = <int>[];

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      bytes.addAll(chunk);
    }
  }

  @override
  Future<void> close() async {}
}

SourceLocation _loc(
  String filePath, {
  int line = 1,
  int column = 1,
  int offset = 0,
  int length = 1,
}) {
  return SourceLocation(
    filePath: filePath,
    offset: offset,
    length: length,
    line: line,
    column: column,
  );
}

void main() {
  group('ConsoleReporter.report', () {
    test('writes nothing for an empty diagnostic list', () async {
      final out = await _capture((r) => r.report(const <Diagnostic>[]));
      expect(out, isEmpty);
    });

    test('writes a single finding under its file header', () async {
      final out = await _capture(
        (r) => r.report([
          Diagnostic(
            ruleId: 'unused_function',
            message: 'Function "foo" is never used.',
            severity: Severity.warning,
            location: _loc('lib/src/foo.dart', line: 3, column: 7),
          ),
        ]),
      );
      expect(
        out,
        'lib/src/foo.dart\n'
        '  3:7 • [warning] unused_function: Function "foo" is never used.\n',
      );
    });

    test(
      'groups multiple diagnostics in one file under a single header, '
      'preserves input order, and renders the correction continuation',
      () async {
        final out = await _capture(
          (r) => r.report([
            Diagnostic(
              ruleId: 'unused_function',
              message: 'Function "foo" is never used.',
              severity: Severity.warning,
              location: _loc('lib/src/foo.dart', line: 10, column: 3),
              correction: 'Remove it or use it.',
            ),
            Diagnostic(
              ruleId: 'unused_class',
              message: 'Class "_Bar" is never used.',
              severity: Severity.info,
              location: _loc('lib/src/foo.dart', line: 2, column: 1),
            ),
          ]),
        );
        expect(
          out,
          'lib/src/foo.dart\n'
          '  10:3 • [warning] unused_function: Function "foo" is never used.\n'
          '    Remove it or use it.\n'
          '  2:1 • [info] unused_class: Class "_Bar" is never used.\n',
        );
      },
    );

    test('emits one header per file in first-seen order and preserves '
        'per-file input order across files', () async {
      final out = await _capture(
        (r) => r.report([
          Diagnostic(
            ruleId: 'unused_function',
            message: 'm1',
            severity: Severity.warning,
            location: _loc('lib/b.dart', line: 1, column: 1),
          ),
          Diagnostic(
            ruleId: 'unused_function',
            message: 'm2',
            severity: Severity.warning,
            location: _loc('lib/a.dart', line: 5, column: 2),
          ),
          Diagnostic(
            ruleId: 'unused_function',
            message: 'm3',
            severity: Severity.error,
            location: _loc('lib/b.dart', line: 9, column: 4),
          ),
        ]),
      );
      expect(
        out,
        'lib/b.dart\n'
        '  1:1 • [warning] unused_function: m1\n'
        '  9:4 • [error] unused_function: m3\n'
        'lib/a.dart\n'
        '  5:2 • [warning] unused_function: m2\n',
      );
    });

    test('handles unicode file paths verbatim', () async {
      final out = await _capture(
        (r) => r.report([
          Diagnostic(
            ruleId: 'unused_function',
            message: 'Function "héllo" is never used.',
            severity: Severity.warning,
            location: _loc('lib/src/フー/bär.dart', line: 4, column: 8),
          ),
        ]),
      );
      expect(
        out,
        'lib/src/フー/bär.dart\n'
        '  4:8 • [warning] unused_function: Function "héllo" is never used.\n',
      );
    });
  });
}
