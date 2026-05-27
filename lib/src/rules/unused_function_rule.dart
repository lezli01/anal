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

part 'unused_function/class_member_collector.dart';
part 'unused_function/constructor_collector.dart';
part 'unused_function/extension_member_collector.dart';
part 'unused_function/local_function_collector.dart';
part 'unused_function/top_level_function_collector.dart';

/// Flags function declarations that are never referenced across the
/// analyzed file set.
///
/// The rule runs once per analysis run with every resolved compilation
/// unit in scope. Three kinds of declarations are inspected, each by a
/// dedicated collector:
///
/// * **Top-level private functions** (identifier begins with `_`) — only
///   when the enclosing library has no `part` files, because otherwise a
///   sibling part could legitimately reference the function. See
///   [_TopLevelFunctionCollector].
/// * **Local function declarations** — functions declared inside another
///   function or method body. See [_LocalFunctionCollector].
/// * **Constructor declarations** on classes and enums (generative,
///   named, factory, and redirecting forms). See [_ConstructorCollector].
///
/// A declaration is considered "used" if its [Element] appears in the
/// global reference set built by [_GlobalReferenceCollector], which
/// walks every unit in the [MultiFileAnalysisContext] and registers the
/// resolved element of every reference-bearing AST node.
///
/// The rule deliberately ignores public top-level functions, methods,
/// getters, setters, operators, the library's `main` entry point,
/// `external` declarations, and any declaration annotated with
/// `@pragma('vm:entry-point')`.
///
/// To avoid duplicate noise with the `unused_class` rule, a candidate is
/// also skipped when its enclosing class element is itself a private,
/// unreferenced declaration: `unused_class` already flags that class,
/// and re-flagging every member of it would just repeat the report.
class UnusedFunctionRule implements MultiFileAnalyzerRule {
  /// Creates an instance of the rule. Stateless and `const`-constructible.
  const UnusedFunctionRule();

  @override
  String get id => 'unused_function';

  @override
  String get description =>
      'Flags function declarations that are never referenced across the '
      'analyzed file set.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) {
    final globalReferences = <Element>{};
    for (final unit in context.units) {
      unit.unit.accept(_GlobalReferenceCollector(globalReferences));
    }

    const collectors = <_UnusedFunctionCandidateCollector>[
      _TopLevelFunctionCollector(),
      _LocalFunctionCollector(),
      _ConstructorCollector(),
      _ExtensionMemberCollector(),
      _ClassMemberCollector(),
    ];

    final diagnostics = <Diagnostic>[];
    for (final unit in context.units) {
      for (final collector in collectors) {
        for (final candidate in collector.collect(unit)) {
          if (globalReferences.contains(candidate.element)) continue;
          if (_enclosingClassIsUnflaggedUnreferencedPrivate(
            candidate.element,
            globalReferences,
          )) {
            continue;
          }
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

  bool _enclosingClassIsUnflaggedUnreferencedPrivate(
    Element element,
    Set<Element> globalReferences,
  ) {
    final enclosing = element.enclosingElement;
    final String? name;
    if (enclosing is InterfaceElement) {
      name = enclosing.name;
    } else if (enclosing is ExtensionElement) {
      name = enclosing.name;
    } else {
      return false;
    }
    if (name == null || !name.startsWith('_')) return false;
    return !globalReferences.contains(enclosing);
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
      message: 'The ${candidate.kindLabel} "$name" is declared but never used.',
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

bool _hasVmEntryPointPragma(NodeList<Annotation> metadata) {
  for (final annotation in metadata) {
    final identifier = annotation.name;
    final simpleName = identifier is SimpleIdentifier
        ? identifier.name
        : identifier is PrefixedIdentifier
        ? identifier.identifier.name
        : '';
    if (simpleName != 'pragma') continue;
    final arguments = annotation.arguments;
    if (arguments == null || arguments.arguments.isEmpty) continue;
    final first = arguments.arguments.first;
    if (first is StringLiteral && first.stringValue == 'vm:entry-point') {
      return true;
    }
  }
  return false;
}

/// Collector contract for the candidate-discovery half of
/// [UnusedFunctionRule].
///
/// Each implementation owns a single declaration kind (top-level
/// functions, local functions, constructors, ...) and yields a
/// [_Candidate] per declaration that the rule's dispatch site should
/// then test against the global reference set.
abstract class _UnusedFunctionCandidateCollector {
  /// Yields the candidates the implementation discovered in [unit].
  Iterable<_Candidate> collect(ResolvedUnitResult unit);
}

/// A declaration the rule may flag if its [element] is not referenced.
///
/// [nameToken] is the source [Token] used as the diagnostic anchor (the
/// declaration's identifier; for unnamed default constructors, the
/// class name token). [kindLabel] is the human-readable kind that
/// appears in the diagnostic message (e.g. `top-level function`,
/// `local function`, `constructor`).
class _Candidate {
  final Token nameToken;
  final Element element;
  final String kindLabel;

  const _Candidate({
    required this.nameToken,
    required this.element,
    required this.kindLabel,
  });
}

/// Walks an entire [MultiFileAnalysisContext] and records every element
/// reached through a reference-bearing AST node.
///
/// Compared with the previous single-unit `_ReferenceCollector`, this
/// visitor inspects the AST node kinds that resolve to executable
/// elements outside of plain [SimpleIdentifier] usage — operator and
/// index expressions, constructor invocations and redirects, named
/// types, and explicit member accesses — so that cross-unit references
/// land in the same global set the dispatch site queries.
class _GlobalReferenceCollector extends RecursiveAstVisitor<void> {
  final Set<Element> sink;

  _GlobalReferenceCollector(this.sink);

  void _add(Element? element) {
    if (element != null) sink.add(element);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    _add(node.element);
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitNamedType(NamedType node) {
    _add(node.element);
    super.visitNamedType(node);
  }

  @override
  void visitConstructorName(ConstructorName node) {
    _add(node.element);
    super.visitConstructorName(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    _add(node.constructorName.element);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitRedirectingConstructorInvocation(
    RedirectingConstructorInvocation node,
  ) {
    _add(node.element);
    super.visitRedirectingConstructorInvocation(node);
  }

  @override
  void visitSuperConstructorInvocation(SuperConstructorInvocation node) {
    _add(node.element);
    super.visitSuperConstructorInvocation(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _add(node.redirectedConstructor?.element);
    // Skip the class-name anchor (`typeName`) — declaring a constructor
    // is not a "use" of its enclosing class, and counting it would make
    // every class with at least one declared constructor look
    // referenced by itself. Visit the remaining children manually.
    node.metadata.accept(this);
    node.parameters.accept(this);
    node.initializers.accept(this);
    node.redirectedConstructor?.accept(this);
    node.body.accept(this);
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    _add(node.element);
    super.visitBinaryExpression(node);
  }

  @override
  void visitPrefixExpression(PrefixExpression node) {
    _add(node.element);
    super.visitPrefixExpression(node);
  }

  @override
  void visitPostfixExpression(PostfixExpression node) {
    _add(node.element);
    super.visitPostfixExpression(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    _add(node.element);
    super.visitIndexExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _add(node.propertyName.element);
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _add(node.element);
    super.visitPrefixedIdentifier(node);
  }
}
