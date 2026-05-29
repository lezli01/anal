import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/diagnostic_suppression.dart';
import 'package:anal/src/severity.dart';
import 'package:anal/src/source_location.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a [Diagnostic] with just the fields the suppressor inspects
/// ([Diagnostic.ruleId] and [SourceLocation.filePath]); everything else is
/// filler so the constructed value is well-formed.
Diagnostic _diag(String ruleId, String filePath) {
  return Diagnostic(
    ruleId: ruleId,
    message: '$ruleId @ $filePath',
    severity: Severity.warning,
    location: SourceLocation(
      filePath: filePath,
      offset: 0,
      length: 0,
      line: 1,
      column: 1,
    ),
  );
}

/// Convenience projection used by the assertions below.
List<(String, String)> _pairs(Iterable<Diagnostic> diagnostics) => [
  for (final d in diagnostics) (d.ruleId, d.location.filePath),
];

void main() {
  group('suppressFindingsInUnusedSourceFiles', () {
    test('returns an empty list unchanged', () {
      expect(suppressFindingsInUnusedSourceFiles(const []), isEmpty);
    });

    test('is a no-op when no unused_source_file finding is present', () {
      final input = <Diagnostic>[
        _diag('unused_class', '/proj/lib/src/a.dart'),
        _diag('unused_function', '/proj/lib/src/a.dart'),
        _diag('some_other_rule', '/proj/lib/src/a.dart'),
      ];

      final result = suppressFindingsInUnusedSourceFiles(input);

      // Same content survives; nothing is dropped.
      expect(_pairs(result), _pairs(input));
    });

    test(
      'drops unused_class and unused_function findings inside a flagged file',
      () {
        const dead = '/proj/lib/src/orphan.dart';
        final input = <Diagnostic>[
          _diag('unused_source_file', dead),
          _diag('unused_class', dead),
          _diag('unused_function', dead),
        ];

        final result = suppressFindingsInUnusedSourceFiles(input);

        // Only the file-level finding survives.
        expect(_pairs(result), [('unused_source_file', dead)]);
      },
    );

    test('keeps findings in files that were not flagged', () {
      const dead = '/proj/lib/src/orphan.dart';
      const alive = '/proj/lib/src/alive.dart';
      final input = <Diagnostic>[
        _diag('unused_source_file', dead),
        _diag('unused_class', dead),
        _diag('unused_function', dead),
        _diag('unused_class', alive),
        _diag('unused_function', alive),
      ];

      final result = suppressFindingsInUnusedSourceFiles(input);

      expect(_pairs(result), [
        ('unused_source_file', dead),
        ('unused_class', alive),
        ('unused_function', alive),
      ]);
    });

    test(
      'preserves _internal errors and unrelated rules in a flagged file',
      () {
        const dead = '/proj/lib/src/orphan.dart';
        final input = <Diagnostic>[
          _diag('unused_source_file', dead),
          _diag('_internal', dead),
          _diag('some_other_rule', dead),
          _diag('unused_class', dead),
        ];

        final result = suppressFindingsInUnusedSourceFiles(input);

        // The file-level finding, the parse/resolve error, and the unrelated
        // rule all survive; only the nested unused_class finding is dropped.
        expect(_pairs(result), [
          ('unused_source_file', dead),
          ('_internal', dead),
          ('some_other_rule', dead),
        ]);
      },
    );

    test('preserves relative order of the survivors', () {
      const dead = '/proj/lib/src/orphan.dart';
      const alive = '/proj/lib/src/alive.dart';
      final input = <Diagnostic>[
        _diag('unused_function', alive),
        _diag('unused_class', dead),
        _diag('unused_source_file', dead),
        _diag('unused_class', alive),
        _diag('unused_function', dead),
      ];

      final result = suppressFindingsInUnusedSourceFiles(input);

      expect(_pairs(result), [
        ('unused_function', alive),
        ('unused_source_file', dead),
        ('unused_class', alive),
      ]);
    });

    test('handles multiple flagged files independently', () {
      const dead1 = '/proj/lib/src/orphan1.dart';
      const dead2 = '/proj/lib/src/orphan2.dart';
      const alive = '/proj/lib/src/alive.dart';
      final input = <Diagnostic>[
        _diag('unused_source_file', dead1),
        _diag('unused_source_file', dead2),
        _diag('unused_class', dead1),
        _diag('unused_function', dead2),
        _diag('unused_class', alive),
      ];

      final result = suppressFindingsInUnusedSourceFiles(input);

      expect(_pairs(result), [
        ('unused_source_file', dead1),
        ('unused_source_file', dead2),
        ('unused_class', alive),
      ]);
    });
  });
}
