part of '../unused_function_rule.dart';

/// Collector for function declarations nested inside another function or
/// method body.
///
/// Every nested [FunctionDeclarationStatement] whose name is not `main`,
/// is not `external`, and is not annotated with
/// `@pragma('vm:entry-point')` is a candidate. References to a local
/// function can only exist inside the enclosing function body, so the
/// global reference index built by the rule is a strict superset of the
/// references that could plausibly bind it — meaning the same
/// "not-in-global-reference-set" check the rule applies to top-level
/// candidates is sound for locals too. Override-awareness does not apply
/// to local functions.
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
    if (_isCandidate(declaration)) {
      final element = declaration.declaredFragment?.element;
      if (element != null) {
        sink.add(
          _Candidate(
            nameToken: declaration.name,
            element: element,
            kindLabel: 'local',
          ),
        );
      }
    }
    super.visitFunctionDeclarationStatement(node);
  }

  bool _isCandidate(FunctionDeclaration declaration) {
    final name = declaration.name.lexeme;
    if (name == 'main') return false;
    if (declaration.externalKeyword != null) return false;
    if (_hasVmEntryPointPragma(declaration.metadata)) return false;
    return true;
  }
}
