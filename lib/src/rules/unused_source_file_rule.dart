import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as p;

import '../diagnostic.dart';
import '../multi_file_analysis_context.dart';
import '../multi_file_analyzer_rule.dart';
import '../severity.dart';
import '../source_location.dart';

/// Flags Dart source files that are never reached from any entry point in the
/// analyzed set.
///
/// The rule is intentionally cross-file: per the frame's multi-file dispatch
/// model, a single invocation sees every resolved compilation unit at once and
/// can reason about reachability between them. The algorithm has four steps:
///
/// 1. **Classify** every analyzed unit's path as an *entry point* or a
///    *non-entry-point candidate*. Entry points are files under `bin/**` or
///    `test/**`, files that declare a top-level `main` function, and files
///    that make up the package's public surface — `lib/<package>.dart` and
///    any other file sitting directly under `lib/` (i.e. not nested in a
///    subdirectory such as `lib/src/`). Everything else, typically
///    `lib/src/**`, is a candidate.
/// 2. **Build a directed graph** in which each unit points to the absolute,
///    normalized paths of every file it pulls in via `ImportDirective`,
///    `ExportDirective`, or `PartDirective` and whose resolved URI lies inside
///    the analyzed set. URIs that resolve outside the analyzed set (`dart:`
///    libraries, dependencies, files excluded from the run) are dropped.
/// 3. **Compute reachability** from the entry-point set with a breadth-first
///    search over that graph.
/// 4. **Emit** one [Diagnostic] per non-entry-point candidate that is
///    unreachable, located at offset `0` / line `1` / column `1` of the file
///    so the message is anchored at the top of the source.
///
/// Generated-file basenames (`*.g.dart`, `*.freezed.dart`) are skipped
/// defensively even though the runner's default excludes already drop them,
/// so consumers that disable those defaults still avoid noisy false
/// positives on generated artifacts.
///
/// Diagnostics are sorted by file path so reports are deterministic for a
/// given input set.
class UnusedSourceFileRule implements MultiFileAnalyzerRule {
  /// Creates an instance of the rule. Stateless and `const`-constructible.
  const UnusedSourceFileRule();

  @override
  String get id => 'unused_source_file';

  @override
  String get description =>
      'Flags Dart source files that are never imported, exported, or used as '
      'a part by any entry point in the analyzed set.';

  @override
  Severity get defaultSeverity => Severity.warning;

  @override
  Iterable<Diagnostic> analyze(MultiFileAnalysisContext context) {
    final analyzed = context.analyzedFilePaths;
    if (analyzed.isEmpty) return const <Diagnostic>[];

    final unitsByPath = <String, ResolvedUnitResult>{};
    for (final unit in context.units) {
      unitsByPath[unit.path] = unit;
    }

    final entryPoints = <String>{};
    for (final path in analyzed) {
      final unit = unitsByPath[path];
      if (unit != null && _hasTopLevelMain(unit.unit)) {
        entryPoints.add(path);
        continue;
      }
      if (_isEntryPointByPath(path)) {
        entryPoints.add(path);
      }
    }

    final adjacency = <String, Set<String>>{};
    for (final path in analyzed) {
      adjacency[path] = _outgoingEdges(unitsByPath[path], analyzed);
    }

    final reachable = <String>{...entryPoints};
    final queue = <String>[...entryPoints];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final outgoing = adjacency[current];
      if (outgoing == null) continue;
      for (final next in outgoing) {
        if (reachable.add(next)) {
          queue.add(next);
        }
      }
    }

    final diagnostics = <Diagnostic>[];
    for (final path in analyzed) {
      if (entryPoints.contains(path)) continue;
      if (_isGenerated(path)) continue;
      if (reachable.contains(path)) continue;
      diagnostics.add(_buildDiagnostic(path));
    }

    diagnostics.sort(
      (a, b) => a.location.filePath.compareTo(b.location.filePath),
    );
    return diagnostics;
  }

  bool _hasTopLevelMain(CompilationUnit unit) {
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration &&
          declaration.name.lexeme == 'main') {
        return true;
      }
    }
    return false;
  }

  bool _isEntryPointByPath(String filePath) {
    final segments = p.split(filePath);
    if (segments.isEmpty) return false;

    var anchorIndex = -1;
    for (var i = 0; i < segments.length - 1; i++) {
      final seg = segments[i];
      if (seg == 'bin' || seg == 'test' || seg == 'lib') {
        anchorIndex = i;
      }
    }
    if (anchorIndex < 0) return false;

    final anchor = segments[anchorIndex];
    final remaining = segments.length - anchorIndex - 1;
    if (anchor == 'bin' || anchor == 'test') {
      return remaining >= 1;
    }
    // anchor == 'lib': only direct children (lib/<file>.dart) are entry points.
    return remaining == 1;
  }

  Set<String> _outgoingEdges(
    ResolvedUnitResult? unit,
    Set<String> analyzedFilePaths,
  ) {
    if (unit == null) return const <String>{};
    final out = <String>{};
    for (final directive in unit.unit.directives) {
      final target = _resolveDirectiveTarget(directive);
      if (target == null) continue;
      final normalized = p.normalize(target);
      if (analyzedFilePaths.contains(normalized)) {
        out.add(normalized);
      }
    }
    return out;
  }

  String? _resolveDirectiveTarget(Directive directive) {
    DirectiveUri? uri;
    if (directive is ImportDirective) {
      uri = directive.libraryImport?.uri;
    } else if (directive is ExportDirective) {
      uri = directive.libraryExport?.uri;
    } else if (directive is PartDirective) {
      uri = directive.partInclude?.uri;
    }
    if (uri is DirectiveUriWithSource) {
      return uri.source.fullName;
    }
    return null;
  }

  bool _isGenerated(String filePath) {
    final base = p.basename(filePath);
    return base.endsWith('.g.dart') || base.endsWith('.freezed.dart');
  }

  Diagnostic _buildDiagnostic(String filePath) {
    final relative = p.relative(filePath);
    return Diagnostic(
      ruleId: id,
      message:
          'The source file "$relative" is never imported, exported, or used '
          'as a part.',
      severity: defaultSeverity,
      location: SourceLocation(
        filePath: filePath,
        offset: 0,
        length: 0,
        line: 1,
        column: 1,
      ),
      correction: 'Remove the file or reference it from an entry point.',
    );
  }
}
