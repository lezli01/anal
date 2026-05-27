import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

import 'anal_options.dart';
import 'analysis_context.dart';
import 'analyzer_rule.dart';
import 'diagnostic.dart';
import 'rule_registry.dart';
import 'severity.dart';
import 'source_location.dart';

/// Orchestrator that walks the configured paths, parses each Dart file, and
/// dispatches the registered [AnalyzerRule]s against it.
///
/// One [AnalysisRunner] is constructed per run. The runner is stateless across
/// runs: build a new one if you need to analyze again.
///
/// Parse and resolve failures for a single file are converted into a
/// [Diagnostic] with `ruleId` `'_internal'` and [Severity.error] rather than
/// thrown out of [run]. That keeps the CLI's exit semantics — non-zero iff
/// any diagnostic is an error — consistent across "the rule fired" and "the
/// file could not be analyzed".
class AnalysisRunner {
  /// Registry of rules to dispatch against every resolved file.
  final RuleRegistry registry;

  /// Configuration controlling which paths are inspected and which rules are
  /// enabled for this run.
  final AnalOptions options;

  /// Creates a runner bound to [registry] and [options].
  AnalysisRunner({required this.registry, required this.options});

  /// Resolves [AnalOptions.includePaths] to a concrete list of `.dart` files,
  /// drops anything matched by [AnalOptions.excludePaths], parses each file
  /// through `package:analyzer`, dispatches each enabled rule, and returns
  /// the accumulated diagnostics.
  Future<List<Diagnostic>> run() async {
    final files = _resolveFiles();
    if (files.isEmpty) return <Diagnostic>[];

    final enabled = options.enabledRuleIds;
    final rules = <AnalyzerRule>[
      for (final rule in registry.rules)
        if (enabled.isEmpty || enabled.contains(rule.id)) rule,
    ];

    final collection = AnalysisContextCollection(
      includedPaths: files,
      sdkPath: _resolveSdkPath(),
    );
    final diagnostics = <Diagnostic>[];

    for (final file in files) {
      try {
        final context = collection.contextFor(file);
        final unitResult = await context.currentSession.getResolvedUnit(file);
        if (unitResult is! ResolvedUnitResult) {
          diagnostics.add(
            _internalError(
              file,
              'Failed to resolve unit (${unitResult.runtimeType}).',
            ),
          );
          continue;
        }
        final ruleContext = AnalysisContext(unit: unitResult, filePath: file);
        for (final rule in rules) {
          try {
            diagnostics.addAll(rule.analyze(ruleContext));
          } on Object catch (error) {
            diagnostics.add(
              _internalError(
                file,
                'Rule "${rule.id}" threw during analysis: $error',
              ),
            );
          }
        }
      } on Object catch (error) {
        diagnostics.add(_internalError(file, 'Could not analyze file: $error'));
      }
    }

    return diagnostics;
  }

  List<String> _resolveFiles() {
    final excludeGlobs = <Glob>[
      for (final pattern in options.excludePaths) Glob(_toPosix(pattern)),
    ];

    final found = <String>{};
    for (final include in options.includePaths) {
      final absolute = p.normalize(
        p.isAbsolute(include) ? include : p.absolute(include),
      );
      final type = FileSystemEntity.typeSync(absolute);
      if (type == FileSystemEntityType.file) {
        if (absolute.endsWith('.dart')) found.add(absolute);
      } else if (type == FileSystemEntityType.directory) {
        for (final entity in Directory(
          absolute,
        ).listSync(recursive: true, followLinks: false)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            found.add(p.normalize(entity.path));
          }
        }
      } else {
        // Treat as a glob pattern relative to the current directory.
        final glob = Glob(include);
        for (final entity in glob.listSync(followLinks: false)) {
          if (entity is File && entity.path.endsWith('.dart')) {
            found.add(p.normalize(p.absolute(entity.path)));
          }
        }
      }
    }

    final filtered = <String>[
      for (final file in found)
        if (!_isExcluded(file, excludeGlobs)) file,
    ]..sort();
    return filtered;
  }

  bool _isExcluded(String file, List<Glob> globs) {
    if (globs.isEmpty) return false;
    final candidates = <String>[
      _toPosix(p.basename(file)),
      _toPosix(p.relative(file, from: Directory.current.path)),
      _toPosix(file),
    ];
    for (final glob in globs) {
      for (final candidate in candidates) {
        if (glob.matches(candidate)) return true;
      }
    }
    return false;
  }

  String _toPosix(String path) => p.normalize(path).replaceAll(r'\', '/');

  /// Best-effort lookup of the Dart SDK directory used to resolve `dart:`
  /// imports during analysis.
  ///
  /// `package:analyzer`'s default of `dirname(dirname(Platform.resolvedExecutable))`
  /// only works when the host is the `dart` CLI. Under `flutter test`
  /// `Platform.resolvedExecutable` points into the Flutter engine cache, so
  /// we fall back to walking up the executable path looking for the bundled
  /// `bin/cache/dart-sdk` directory before giving up and returning the
  /// default — preserving analyzer's behavior for direct `dart run` users.
  String? _resolveSdkPath() {
    final defaultPath = p.dirname(p.dirname(Platform.resolvedExecutable));
    if (_looksLikeSdk(defaultPath)) return defaultPath;

    var dir = p.dirname(Platform.resolvedExecutable);
    while (true) {
      final candidate = p.join(dir, 'bin', 'cache', 'dart-sdk');
      if (_looksLikeSdk(candidate)) return candidate;
      final parent = p.dirname(dir);
      if (parent == dir) return defaultPath;
      dir = parent;
    }
  }

  bool _looksLikeSdk(String sdkPath) {
    return FileSystemEntity.isFileSync(
      p.join(sdkPath, 'lib', '_internal', 'allowed_experiments.json'),
    );
  }

  Diagnostic _internalError(String filePath, String message) {
    return Diagnostic(
      ruleId: '_internal',
      message: message,
      severity: Severity.error,
      location: SourceLocation(
        filePath: filePath,
        offset: 0,
        length: 0,
        line: 1,
        column: 1,
      ),
    );
  }
}
