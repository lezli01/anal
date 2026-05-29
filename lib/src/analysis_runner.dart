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
import 'diagnostic_suppression.dart';
import 'multi_file_analysis_context.dart';
import 'multi_file_analyzer_rule.dart';
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
  /// partitions them into a reportable subset (everything not matched by
  /// [AnalOptions.excludePaths]) and a supplementary subset (the files the
  /// exclude globs filtered out), parses each file in *both* sets through
  /// `package:analyzer` so cross-file rules can resolve references into
  /// excluded files, dispatches each enabled single-file rule against
  /// reportable files only, dispatches each enabled multi-file rule once
  /// over the combined context, and returns the accumulated diagnostics
  /// after a final cross-rule pass
  /// ([suppressFindingsInUnusedSourceFiles]) drops `unused_class` /
  /// `unused_function` findings nested inside a file `unused_source_file`
  /// already reported as a whole.
  Future<List<Diagnostic>> run() async {
    final (reportable, supplementary) = _resolveFiles();
    if (reportable.isEmpty) return <Diagnostic>[];

    final enabled = options.enabledRuleIds;
    final rules = <AnalyzerRule>[
      for (final rule in registry.rules)
        if (enabled.isEmpty || enabled.contains(rule.id)) rule,
    ];

    final multiFileRules = <MultiFileAnalyzerRule>[
      for (final rule in registry.multiFileRules)
        if (enabled.isEmpty || enabled.contains(rule.id)) rule,
    ];

    final allPaths = <String>[...reportable, ...supplementary]..sort();
    final reportableSet = reportable.toSet();
    final collection = AnalysisContextCollection(
      includedPaths: allPaths,
      sdkPath: _resolveSdkPath(),
    );
    final diagnostics = <Diagnostic>[];
    final resolvedUnits = <ResolvedUnitResult>[];

    for (final file in allPaths) {
      final isReportable = reportableSet.contains(file);
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
        resolvedUnits.add(unitResult);
        if (!isReportable) continue;
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

    if (multiFileRules.isNotEmpty) {
      final analyzedFilePaths = <String>{
        for (final unit in resolvedUnits) unit.path,
      };
      final multiFileContext = MultiFileAnalysisContext(
        units: resolvedUnits,
        analyzedFilePaths: analyzedFilePaths,
        reportableFilePaths: reportableSet.intersection(analyzedFilePaths),
      );
      for (final rule in multiFileRules) {
        try {
          diagnostics.addAll(rule.analyze(multiFileContext));
        } on Object catch (error) {
          diagnostics.add(
            _internalError(
              '',
              'Multi-file rule "${rule.id}" threw during analysis: $error',
            ),
          );
        }
      }
    }

    // Collapse the "unused" rule family's containment hierarchy: when
    // `unused_source_file` reports a whole file, drop the `unused_class` /
    // `unused_function` findings nested inside it so a dead file is
    // reported once rather than once per declaration. (The class → member
    // tier is handled inside `unused_function` itself, which has the
    // element model needed to decide member containment.)
    return suppressFindingsInUnusedSourceFiles(diagnostics);
  }

  /// Returns the absolute, normalized `.dart` paths discovered under
  /// [AnalOptions.includePaths], partitioned into:
  ///
  /// * `reportable` — files that survived the [AnalOptions.excludePaths]
  ///   globs and are therefore eligible for single-file rule dispatch and
  ///   diagnostic emission, and
  /// * `supplementary` — files the exclude globs filtered out. The frame
  ///   still parses/resolves these so cross-file rules can follow
  ///   references into them, but they are not dispatched against directly
  ///   and may not receive diagnostics.
  ///
  /// Both lists are sorted for deterministic ordering.
  (List<String>, List<String>) _resolveFiles() {
    final excludeGlobs = <_ExcludeGlob>[
      for (final pattern in options.excludePaths)
        _ExcludeGlob(_toPosix(pattern)),
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

    final reportable = <String>[];
    final supplementary = <String>[];
    for (final file in found) {
      if (_isExcluded(file, excludeGlobs)) {
        supplementary.add(file);
      } else {
        reportable.add(file);
      }
    }
    reportable.sort();
    supplementary.sort();
    return (reportable, supplementary);
  }

  bool _isExcluded(String file, List<_ExcludeGlob> globs) {
    if (globs.isEmpty) return false;
    final candidates = <String>[
      _toPosix(p.basename(file)),
      _toPosix(p.relative(file, from: Directory.current.path)),
      _toPosix(file),
    ];
    for (final exclude in globs) {
      for (final candidate in candidates) {
        if (exclude.matches(candidate)) return true;
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

class _ExcludeGlob {
  final String pattern;
  final Glob glob;
  final Glob? recursiveBasenameGlob;

  _ExcludeGlob(this.pattern)
    : glob = Glob(pattern),
      recursiveBasenameGlob = pattern.startsWith('**/')
          ? Glob(pattern.substring(3))
          : null;

  bool matches(String candidate) {
    if (glob.matches(candidate)) return true;
    return recursiveBasenameGlob?.matches(candidate) ?? false;
  }
}
