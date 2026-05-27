import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';

import '../diagnostic.dart';
import '../multi_file_analysis_context.dart';
import '../multi_file_analyzer_rule.dart';
import '../severity.dart';
import '../source_location.dart';

part 'unused_function/candidate_collector.dart';
part 'unused_function/local_function_collector.dart';
part 'unused_function/top_level_private_collector.dart';

/// Flags function declarations that are never referenced across the
/// analyzed set of Dart files.
///
/// The rule runs once per analysis run via the multi-file dispatch model:
/// it scans every supplied [ResolvedUnitResult] to build a single global
/// reference index, then runs a fixed set of per-unit candidate
/// collectors against each unit and emits one [Diagnostic] for every
/// candidate whose declared [Element] does not appear in that index.
///
/// Two kinds of declarations are inspected today, via dedicated
/// collectors under `lib/src/rules/unused_function/`:
///
/// * **Top-level private functions** (identifier begins with `_`).
///   Sibling part files are reachable through the multi-file context, so
///   no parts-file exemption is necessary — references inside a part of
///   the same library are observed and the function is not flagged.
/// * **Local function declarations** — functions declared inside another
///   function or method body. References to a local can only appear in
///   the enclosing body, so the global reference index is a sound
///   superset for the same check.
///
/// A function is considered "used" if any of the following resolves
/// (via the analyzer's element model) to its declared element anywhere
/// in the analyzed set: a [SimpleIdentifier], a [NamedType], or a
/// [ConstructorName] / [InstanceCreationExpression]. The constructor
/// hooks ensure invocations such as `MyClass()` register the unnamed
/// constructor element, which is shared infrastructure with future
/// kinds — local and top-level functions themselves resolve through
/// [SimpleIdentifier].
///
/// The rule deliberately ignores public top-level functions, methods,
/// constructors, getters, setters, operators, the library's `main`
/// entry point, `external` functions, and any function annotated with
/// `@pragma('vm:entry-point')`. Override-awareness is delegated to
/// per-kind collectors; the kinds shipped today do not require it.
class UnusedFunctionRule implements MultiFileAnalyzerRule {
  /// Creates an instance of the rule. Stateless and `const`-constructible.
  const UnusedFunctionRule();

  @override
  String get id => 'unused_function';

  @override
  String get description =>
      'Flags function declarations that are never referenced across the '
      'analyzed set of Dart files.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) {
    if (context.units.isEmpty) return const <Diagnostic>[];

    final globalReferences = <Element>{};
    final referenceCollector = _ReferenceCollector(globalReferences);
    for (final unit in context.units) {
      unit.unit.accept(referenceCollector);
    }

    const collectors = <_UnusedFunctionCandidateCollector>[
      _TopLevelPrivateCollector(),
      _LocalFunctionCollector(),
    ];

    final diagnostics = <Diagnostic>[];
    for (final unit in context.units) {
      for (final collector in collectors) {
        for (final candidate in collector.collect(unit)) {
          if (globalReferences.contains(candidate.element)) continue;
          diagnostics.add(
            _buildDiagnostic(
              candidate: candidate,
              filePath: unit.path,
              lineInfo: unit.lineInfo,
            ),
          );
        }
      }
    }

    diagnostics.sort((a, b) {
      final byPath = a.location.filePath.compareTo(b.location.filePath);
      if (byPath != 0) return byPath;
      final byLine = a.location.line.compareTo(b.location.line);
      if (byLine != 0) return byLine;
      return a.location.column.compareTo(b.location.column);
    });

    return diagnostics;
  }

  Diagnostic _buildDiagnostic({
    required _Candidate candidate,
    required String filePath,
    required LineInfo lineInfo,
  }) {
    final nameToken = candidate.nameToken;
    final name = nameToken.lexeme;
    final offset = nameToken.offset;
    final length = nameToken.length;
    final location = lineInfo.getLocation(offset);
    return Diagnostic(
      ruleId: 'unused_function',
      message:
          'The ${candidate.kindLabel} function "$name" is declared but '
          'never used.',
      severity: Severity.warning,
      location: SourceLocation(
        filePath: filePath,
        offset: offset,
        length: length,
        line: location.lineNumber,
        column: location.columnNumber,
      ),
      correction: 'Remove "$name" or reference it.',
    );
  }
}

class _ReferenceCollector extends RecursiveAstVisitor<void> {
  final Set<Element> sink;

  _ReferenceCollector(this.sink);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final element = node.element;
    if (element != null) sink.add(element);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    final element = node.element;
    if (element != null) sink.add(element);
    super.visitNamedType(node);
  }

  @override
  void visitConstructorName(ConstructorName node) {
    final element = node.element;
    if (element != null) sink.add(element);
    super.visitConstructorName(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    if (element != null) sink.add(element);
    super.visitInstanceCreationExpression(node);
  }
}
