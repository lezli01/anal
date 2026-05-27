import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/multi_file_analyzer_rule.dart';
import 'package:anal/src/severity.dart';
import 'package:anal/src/source_location.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubMultiFileRule implements MultiFileAnalyzerRule {
  _StubMultiFileRule({
    this.id = 'stub_multi',
    this.description = 'stub',
    this.defaultSeverity = Severity.info,
    this.diagnostics = const <Diagnostic>[],
  });

  @override
  final String id;

  @override
  final String description;

  @override
  final Severity defaultSeverity;

  final List<Diagnostic> diagnostics;

  MultiFileAnalysisContext? lastContext;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) {
    lastContext = context;
    return diagnostics;
  }
}

void main() {
  group('MultiFileAnalysisContext', () {
    test('exposes the supplied units and analyzed file paths', () {
      final context = MultiFileAnalysisContext(
        units: const <ResolvedUnitResult>[],
        analyzedFilePaths: <String>{'/abs/a.dart', '/abs/b.dart'},
      );

      expect(context.units, isEmpty);
      expect(context.analyzedFilePaths, <String>{'/abs/a.dart', '/abs/b.dart'});
    });

    test('wraps units in an unmodifiable list', () {
      final context = MultiFileAnalysisContext(
        units: <ResolvedUnitResult>[],
        analyzedFilePaths: const <String>{},
      );

      expect(() => context.units.clear(), throwsUnsupportedError);
    });

    test('wraps analyzed file paths in an unmodifiable set', () {
      final context = MultiFileAnalysisContext(
        units: const <ResolvedUnitResult>[],
        analyzedFilePaths: <String>{'/abs/a.dart'},
      );

      expect(
        () => context.analyzedFilePaths.add('/abs/b.dart'),
        throwsUnsupportedError,
      );
    });

    test('does not observe later mutations of the input collections', () {
      final units = <ResolvedUnitResult>[];
      final paths = <String>{'/abs/a.dart'};
      final context = MultiFileAnalysisContext(
        units: units,
        analyzedFilePaths: paths,
      );

      paths.add('/abs/b.dart');

      expect(context.analyzedFilePaths, <String>{'/abs/a.dart'});
      expect(context.units, isEmpty);
    });
  });

  group('MultiFileAnalyzerRule', () {
    test('exposes the contract values supplied by the implementation', () {
      final rule = _StubMultiFileRule(
        id: 'unused_source_file',
        description: 'reports source files that are never imported',
        defaultSeverity: Severity.warning,
      );

      expect(rule.id, 'unused_source_file');
      expect(rule.description, 'reports source files that are never imported');
      expect(rule.defaultSeverity, Severity.warning);
    });

    test(
      'analyze receives the supplied context and returns its diagnostics',
      () {
        const diagnostic = Diagnostic(
          ruleId: 'stub_multi',
          message: 'found something',
          severity: Severity.info,
          location: SourceLocation(
            filePath: '/abs/a.dart',
            offset: 0,
            length: 1,
            line: 1,
            column: 1,
          ),
        );
        final rule = _StubMultiFileRule(diagnostics: <Diagnostic>[diagnostic]);
        final context = MultiFileAnalysisContext(
          units: const <ResolvedUnitResult>[],
          analyzedFilePaths: const <String>{'/abs/a.dart'},
        );

        final result = rule.analyze(context).toList();

        expect(rule.lastContext, same(context));
        expect(result, <Diagnostic>[diagnostic]);
      },
    );

    test('analyze may return an empty iterable when nothing is found', () {
      final rule = _StubMultiFileRule();
      final context = MultiFileAnalysisContext(
        units: const <ResolvedUnitResult>[],
        analyzedFilePaths: const <String>{},
      );

      expect(rule.analyze(context), isEmpty);
    });
  });
}
