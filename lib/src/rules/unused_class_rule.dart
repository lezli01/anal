import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/line_info.dart';

import '../analysis_context.dart';
import '../analyzer_rule.dart';
import '../diagnostic.dart';
import '../severity.dart';
import '../source_location.dart';

/// Flags file-local class, mixin, enum, and extension-type declarations that
/// are never referenced.
///
/// The rule is intentionally file-local: per the frame's dispatch model, a
/// rule sees one resolved compilation unit at a time and cannot reason about
/// references in sibling files. Four kinds of top-level declarations are
/// inspected:
///
/// * `ClassDeclaration` — covers `class`, `abstract class`, and `base`,
///   `final`, `sealed`, and `interface` modifiers (all surface as
///   `ClassDeclaration` in the AST).
/// * `MixinDeclaration`.
/// * `EnumDeclaration`.
/// * `ExtensionTypeDeclaration`.
///
/// Only **private** declarations (identifier begins with `_`) are
/// candidates, and only when the enclosing library has no `part` files,
/// because otherwise a sibling part could legitimately reference the
/// declaration.
///
/// A declaration is considered "used" if any `SimpleIdentifier` in the
/// compilation unit resolves (via `element`) to its declared element.
/// This captures type annotations, constructor invocations, `extends`,
/// `implements`, `with`, and `on` clauses, `is`/`as` checks, static-member
/// access, enum-value access, and constructor or static tear-offs.
///
/// The rule deliberately ignores:
///
/// * public top-level declarations (names not starting with `_`);
/// * `ClassTypeAlias` declarations such as `class _Foo = A with B;` —
///   out of scope for the first cut;
/// * `extension` declarations (non-type `ExtensionDeclaration`) — out of
///   scope for the first cut;
/// * declarations annotated with `@pragma('vm:entry-point')`.
class UnusedClassRule implements AnalyzerRule {
  /// Creates an instance of the rule. Stateless and `const`-constructible.
  const UnusedClassRule();

  @override
  String get id => 'unused_class';

  @override
  String get description =>
      'Flags file-local class, mixin, enum, and extension-type declarations '
      'that are never referenced.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(AnalysisContext context) {
    final compilationUnit = context.unit.unit;
    final libraryElement = context.unit.libraryElement;
    final lineInfo = context.unit.lineInfo;
    final filePath = context.filePath;

    if (libraryElement.fragments.length > 1) {
      return const <Diagnostic>[];
    }

    final candidates = <_Candidate>[];
    for (final declaration in compilationUnit.declarations) {
      final candidate = _candidateFor(declaration);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    if (candidates.isEmpty) {
      return const <Diagnostic>[];
    }

    final unitReferences = <Element>{};
    compilationUnit.accept(_ReferenceCollector(unitReferences));

    final diagnostics = <Diagnostic>[];
    for (final candidate in candidates) {
      final element = candidate.element;
      if (element == null) continue;
      if (unitReferences.contains(element)) continue;
      diagnostics.add(
        _buildDiagnostic(
          candidate: candidate,
          filePath: filePath,
          lineInfo: lineInfo,
        ),
      );
    }

    diagnostics.sort((a, b) {
      final byLine = a.location.line.compareTo(b.location.line);
      if (byLine != 0) return byLine;
      return a.location.column.compareTo(b.location.column);
    });

    return diagnostics;
  }

  _Candidate? _candidateFor(CompilationUnitMember declaration) {
    if (declaration is ClassDeclaration) {
      final nameToken = declaration.namePart.typeName;
      if (!_isPrivateName(nameToken.lexeme)) return null;
      if (_hasVmEntryPointPragma(declaration.metadata)) return null;
      return _Candidate(
        nameToken: nameToken,
        element: declaration.declaredFragment?.element,
        kindLabel: 'class',
      );
    }
    if (declaration is MixinDeclaration) {
      if (!_isPrivateName(declaration.name.lexeme)) return null;
      if (_hasVmEntryPointPragma(declaration.metadata)) return null;
      return _Candidate(
        nameToken: declaration.name,
        element: declaration.declaredFragment?.element,
        kindLabel: 'mixin',
      );
    }
    if (declaration is EnumDeclaration) {
      final nameToken = declaration.namePart.typeName;
      if (!_isPrivateName(nameToken.lexeme)) return null;
      if (_hasVmEntryPointPragma(declaration.metadata)) return null;
      return _Candidate(
        nameToken: nameToken,
        element: declaration.declaredFragment?.element,
        kindLabel: 'enum',
      );
    }
    if (declaration is ExtensionTypeDeclaration) {
      // `ExtensionTypeDeclaration.name` is the only name accessor available in
      // analyzer 9.0.0; `primaryConstructor` only exists in analyzer 10+ and
      // `namePart` is not exposed on this node. Deprecation is suppressed
      // because we still need to compile against the full supported range.
      // ignore: deprecated_member_use
      final nameToken = declaration.name;
      if (!_isPrivateName(nameToken.lexeme)) return null;
      if (_hasVmEntryPointPragma(declaration.metadata)) return null;
      return _Candidate(
        nameToken: nameToken,
        element: declaration.declaredFragment?.element,
        kindLabel: 'extension type',
      );
    }
    return null;
  }

  bool _isPrivateName(String name) => name.startsWith('_');

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
      ruleId: 'unused_class',
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

class _Candidate {
  final Token nameToken;
  final Element? element;
  final String kindLabel;

  const _Candidate({
    required this.nameToken,
    required this.element,
    required this.kindLabel,
  });
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
}
