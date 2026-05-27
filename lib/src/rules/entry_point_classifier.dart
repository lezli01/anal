import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// Returns `true` when [unit] declares a top-level `main` function.
///
/// Used to classify a compilation unit as an entry point for the
/// reachability analysis performed by `UnusedSourceFileRule` and the
/// public-top-level candidate gating performed by `UnusedFunctionRule`.
bool hasTopLevelMain(CompilationUnit unit) {
  for (final declaration in unit.declarations) {
    if (declaration is FunctionDeclaration &&
        declaration.name.lexeme == 'main') {
      return true;
    }
  }
  return false;
}

/// Returns `true` when [filePath] is classified as an entry point by its
/// location on disk.
///
/// Files under `bin/**` and `test/**` (any depth) are entry points, as are
/// files sitting directly under `lib/` (`lib/<file>.dart`). Files nested
/// further inside `lib/` (typically `lib/src/**`) are not entry points.
///
/// Path classification is independent of file contents; callers that also
/// want to honour a top-level `main` declaration should combine this with
/// [hasTopLevelMain].
bool isEntryPointByPath(String filePath) {
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
