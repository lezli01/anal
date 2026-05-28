import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String _dartExecutable() {
  final exe = Platform.resolvedExecutable;
  if (p.basenameWithoutExtension(exe) == 'dart') {
    return exe;
  }
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null && flutterRoot.isNotEmpty) {
    return p.join(flutterRoot, 'bin', 'cache', 'dart-sdk', 'bin', 'dart');
  }
  return 'dart';
}

void main() {
  group('--list-rules', () {
    test(
      'prints registered rules and exits 0',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await Process.run(_dartExecutable(), [
          'run',
          'anal',
          '--list-rules',
        ]);

        final stdoutText = result.stdout as String;
        final stderrText = result.stderr as String;

        expect(
          result.exitCode,
          0,
          reason: 'stdout: $stdoutText\nstderr: $stderrText',
        );
        expect(stdoutText, startsWith('Available rules:\n\n'));

        expect(
          stdoutText,
          matches(
            RegExp(r'^  unused_function\s+warning\s+.+$', multiLine: true),
          ),
        );
        expect(
          stdoutText,
          matches(RegExp(r'^  unused_class\s+warning\s+.+$', multiLine: true)),
        );
        expect(
          stdoutText,
          matches(
            RegExp(r'^  unused_source_file\s+warning\s+.+$', multiLine: true),
          ),
        );

        expect(stdoutText, isNot(contains('No issues found')));
        expect(stderrText, isEmpty);

        final classIndex = stdoutText.indexOf('unused_class');
        final functionIndex = stdoutText.indexOf('unused_function');
        final sourceIndex = stdoutText.indexOf('unused_source_file');
        expect(classIndex, greaterThan(-1));
        expect(functionIndex, greaterThan(-1));
        expect(sourceIndex, greaterThan(-1));
        expect(classIndex, lessThan(functionIndex));
        expect(functionIndex, lessThan(sourceIndex));
      },
    );

    test(
      '--list-rules --help still prints usage',
      timeout: const Timeout(Duration(minutes: 2)),
      () async {
        final result = await Process.run(_dartExecutable(), [
          'run',
          'anal',
          '--list-rules',
          '--help',
        ]);

        expect(result.exitCode, 0);
        expect(result.stdout as String, startsWith('Usage:'));
      },
    );
  });
}
