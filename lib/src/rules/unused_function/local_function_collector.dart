part of '../unused_function_rule.dart';

/// Collector for local function declarations.
///
/// Local functions are declarations of the form `void foo() {}` that
/// appear inside another function or method body — surfaced as
/// [FunctionDeclarationStatement] in the AST. Every such declaration
/// is a candidate.
///
/// A declaration is exempt when its name is `main`, when it is declared
/// `external`, or when it carries `@pragma('vm:entry-point')`.
///
/// The diagnostic anchor is the declaration's name [Token].
class _LocalFunctionCollector implements _UnusedFunctionCandidateCollector {
  const _LocalFunctionCollector();

  @override
  Iterable<_Candidate> collect(ResolvedUnitResult unit) {
    final candidates = <_Candidate>[];
    unit.unit.accept(_LocalFunctionVisitor(candidates));
    return candidates;
  }
}

class _LocalFunctionVisitor extends RecursiveAstVisitor<void> {
  final List<_Candidate> sink;

  _LocalFunctionVisitor(this.sink);

  @override
  void visitFunctionDeclarationStatement(FunctionDeclarationStatement node) {
    final declaration = node.functionDeclaration;
    if (_isLocalCandidate(declaration)) {
      final element = declaration.declaredFragment?.element;
      if (element != null) {
        sink.add(
          _Candidate(
            nameToken: declaration.name,
            element: element,
            kindLabel: 'local function',
          ),
        );
      }
    }
    super.visitFunctionDeclarationStatement(node);
  }

  bool _isLocalCandidate(FunctionDeclaration declaration) {
    final name = declaration.name.lexeme;
    if (name == 'main') return false;
    if (declaration.externalKeyword != null) return false;
    if (_hasVmEntryPointPragma(declaration.metadata)) return false;
    return true;
  }
}
