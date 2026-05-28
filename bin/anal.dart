import 'dart:io';

import 'package:anal/src/anal_options.dart';
import 'package:anal/src/analysis_runner.dart';
import 'package:anal/src/reporter.dart';
import 'package:anal/src/rule_registry.dart';
import 'package:anal/src/rules/unused_class_rule.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:anal/src/rules/unused_source_file_rule.dart';
import 'package:anal/src/severity.dart';
import 'package:args/args.dart';

const String _version = '0.3.5'; // x-release-please-version

Future<void> main(List<String> arguments) async {
  final parser = _buildArgParser();

  final ArgResults parsed;
  try {
    parsed = parser.parse(arguments);
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln();
    stderr.writeln(_usage(parser));
    exitCode = 64;
    return;
  }

  if (parsed['help'] as bool) {
    stdout.writeln(_usage(parser));
    return;
  }

  if (parsed['version'] as bool) {
    stdout.writeln(_version);
    return;
  }

  final options = _buildOptions(parsed);

  final registry = RuleRegistry();
  registry.registerMultiFile(UnusedFunctionRule());
  registry.register(UnusedClassRule());
  registry.registerMultiFile(UnusedSourceFileRule());

  final runner = AnalysisRunner(registry: registry, options: options);
  final diagnostics = await runner.run();

  ConsoleReporter(out: stdout).report(diagnostics);

  if (diagnostics.any((d) => d.severity == Severity.error)) {
    exitCode = 1;
  }
}

ArgParser _buildArgParser() {
  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information and exit.',
    )
    ..addFlag(
      'version',
      negatable: false,
      help: 'Print the package version and exit.',
    )
    ..addOption(
      'rules',
      help:
          'Comma-separated list of rule ids to enable. '
          'When omitted, every registered rule is enabled.',
      valueHelp: 'id,id,...',
    )
    ..addMultiOption(
      'exclude',
      help:
          'Glob pattern to exclude from analysis. '
          'May be passed multiple times. '
          'Layered on top of the built-in default excludes unless '
          '--no-default-excludes is given.',
      valueHelp: 'glob',
      splitCommas: false,
    )
    ..addFlag(
      'default-excludes',
      defaultsTo: true,
      negatable: true,
      help:
          'Apply the built-in exclude patterns (*.g.dart, *.freezed.dart). '
          'Use --no-default-excludes to opt out.',
    );
}

AnalOptions _buildOptions(ArgResults parsed) {
  final paths = parsed.rest;
  final excludes = parsed['exclude'] as List<String>;
  final rulesArg = parsed['rules'] as String?;
  final useDefaults = parsed['default-excludes'] as bool;

  const defaults = AnalOptions.defaults();

  final includePaths = paths.isEmpty
      ? defaults.includePaths
      : List<String>.unmodifiable(paths);

  final excludePaths = List<String>.unmodifiable([
    if (useDefaults) ...AnalOptions.defaultExcludePaths,
    ...excludes,
  ]);

  final Set<String> enabledRuleIds;
  if (rulesArg == null || rulesArg.isEmpty) {
    enabledRuleIds = const <String>{};
  } else {
    enabledRuleIds = Set<String>.unmodifiable(
      rulesArg.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
    );
  }

  return AnalOptions(
    includePaths: includePaths,
    excludePaths: excludePaths,
    enabledRuleIds: enabledRuleIds,
  );
}

String _usage(ArgParser parser) {
  return 'Usage: dart run anal [options] [paths...]\n'
      '\n'
      'Static analysis frame for Dart and Flutter projects.\n'
      '\n'
      'Options:\n'
      '${parser.usage}';
}
