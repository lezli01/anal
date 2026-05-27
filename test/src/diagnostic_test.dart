import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/severity.dart';
import 'package:anal/src/source_location.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const location = SourceLocation(
    filePath: '/tmp/foo.dart',
    offset: 10,
    length: 3,
    line: 2,
    column: 5,
  );

  group('Severity', () {
    test('ordering is info < warning < error by index', () {
      expect(Severity.info.index, lessThan(Severity.warning.index));
      expect(Severity.warning.index, lessThan(Severity.error.index));
    });
  });

  group('SourceLocation', () {
    test('two instances with identical fields are ==', () {
      const a = SourceLocation(
        filePath: '/tmp/foo.dart',
        offset: 10,
        length: 3,
        line: 2,
        column: 5,
      );
      const b = SourceLocation(
        filePath: '/tmp/foo.dart',
        offset: 10,
        length: 3,
        line: 2,
        column: 5,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('instances differing in any field are unequal', () {
      const a = SourceLocation(
        filePath: '/tmp/foo.dart',
        offset: 10,
        length: 3,
        line: 2,
        column: 5,
      );
      const b = SourceLocation(
        filePath: '/tmp/foo.dart',
        offset: 11,
        length: 3,
        line: 2,
        column: 5,
      );
      expect(a, isNot(equals(b)));
    });

    test('toString returns "file:line:column"', () {
      expect(location.toString(), '/tmp/foo.dart:2:5');
    });
  });

  group('Diagnostic', () {
    test(
      'two diagnostics with identical fields are == and have equal hashCode',
      () {
        const a = Diagnostic(
          ruleId: 'unused_function',
          message: 'Function "foo" is never used.',
          severity: Severity.warning,
          location: location,
          correction: 'Remove it or use it.',
        );
        const b = Diagnostic(
          ruleId: 'unused_function',
          message: 'Function "foo" is never used.',
          severity: Severity.warning,
          location: location,
          correction: 'Remove it or use it.',
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('diagnostics differing only in correction are unequal', () {
      const a = Diagnostic(
        ruleId: 'unused_function',
        message: 'Function "foo" is never used.',
        severity: Severity.warning,
        location: location,
        correction: 'Remove it.',
      );
      const b = Diagnostic(
        ruleId: 'unused_function',
        message: 'Function "foo" is never used.',
        severity: Severity.warning,
        location: location,
        correction: 'Use it.',
      );
      expect(a, isNot(equals(b)));
    });

    test('null correction is distinct from a non-null correction', () {
      const a = Diagnostic(
        ruleId: 'r',
        message: 'm',
        severity: Severity.info,
        location: location,
      );
      const b = Diagnostic(
        ruleId: 'r',
        message: 'm',
        severity: Severity.info,
        location: location,
        correction: '',
      );
      expect(a, isNot(equals(b)));
    });

    test('toString contains the rule id and message', () {
      const d = Diagnostic(
        ruleId: 'unused_function',
        message: 'Function "foo" is never used.',
        severity: Severity.warning,
        location: location,
      );
      final s = d.toString();
      expect(s, contains('unused_function'));
      expect(s, contains('Function "foo" is never used.'));
    });
  });
}
