import 'dart:convert';
import 'dart:io';

import 'package:anal/anal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Expected (`ruleId`, relative-from-sample-root file path) diagnostic pairs
/// for each sample project. Lists rather than sets, because a sample may
/// emit the same `(rule, file)` pair more than once (e.g. two `unused_function`
/// findings in the same file). Paths use forward slashes so the literals
/// match what the test produces after normalization.
///
/// This fixture doubles as a machine-checked summary of each sample's
/// README "Expected diagnostics" section — keep them in sync.
const Map<String, List<(String, String)>> _expectedDiagnostics = {
  // samples/unused_function: README documents exactly two unused_function
  // diagnostics in lib/unused_function_sample.dart (P1 + P2).
  'unused_function': [
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
  ],
  // samples/unused_class: README documents exactly four unused_class
  // diagnostics in lib/unused_class_sample.dart (P1..P4).
  'unused_class': [
    ('unused_class', 'lib/unused_class_sample.dart'),
    ('unused_class', 'lib/unused_class_sample.dart'),
    ('unused_class', 'lib/unused_class_sample.dart'),
    ('unused_class', 'lib/unused_class_sample.dart'),
  ],
  // samples/unused_source_file: README documents a single unused_source_file
  // diagnostic pointing at lib/src/orphan.dart.
  'unused_source_file': [('unused_source_file', 'lib/src/orphan.dart')],
  // samples/all_rules: README documents one diagnostic per built-in rule.
  'all_rules': [
    ('unused_source_file', 'lib/src/orphan.dart'),
    ('unused_class', 'lib/unused_class_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
  ],
};

/// Directories (relative to each sample root) that must be analyzed when
/// running the sample. Mirrors the invocation in each sample's README.
const Map<String, List<String>> _sampleIncludeDirs = {
  'unused_function': ['lib'],
  'unused_class': ['lib'],
  'unused_source_file': ['lib', 'bin'],
  'all_rules': ['lib'],
};

/// Samples whose entry points use a `package:` self-import. For these we
/// materialise a minimal `.dart_tool/package_config.json` in the temp copy
/// so the import resolves and the multi-file rule sees the full reachability
/// graph.
const Map<String, String> _samplePackageNames = {
  'unused_source_file': 'unused_source_file_sample',
};

RuleRegistry _buildCliRegistry() {
  final registry = RuleRegistry();
  registry.register(UnusedFunctionRule());
  registry.register(UnusedClassRule());
  registry.registerMultiFile(UnusedSourceFileRule());
  return registry;
}

void main() {
  group('sample projects', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('anal_samples_test_');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    for (final entry in _expectedDiagnostics.entries) {
      final sampleName = entry.key;
      final expected = entry.value;

      test('samples/$sampleName emits the (ruleId, file) pairs documented '
          'in its README', () async {
        final sampleSourceDir = Directory(
          p.join(Directory.current.path, 'samples', sampleName),
        );
        expect(
          sampleSourceDir.existsSync(),
          isTrue,
          reason: 'sample directory ${sampleSourceDir.path} is missing',
        );

        final sampleDestDir = Directory(p.join(tempRoot.path, sampleName))
          ..createSync(recursive: true);

        final includeDirs = _sampleIncludeDirs[sampleName]!;
        final destIncludePaths = <String>[];
        for (final relInclude in includeDirs) {
          final src = Directory(p.join(sampleSourceDir.path, relInclude));
          final dst = Directory(p.join(sampleDestDir.path, relInclude))
            ..createSync(recursive: true);
          for (final entity in src.listSync(
            recursive: true,
            followLinks: false,
          )) {
            if (entity is! File) continue;
            if (!entity.path.endsWith('.dart')) continue;
            final rel = p.relative(entity.path, from: src.path);
            final target = File(p.join(dst.path, rel));
            target.parent.createSync(recursive: true);
            target.writeAsStringSync(entity.readAsStringSync());
          }
          destIncludePaths.add(dst.path);
        }

        final packageName = _samplePackageNames[sampleName];
        if (packageName != null) {
          final dartTool = Directory(p.join(sampleDestDir.path, '.dart_tool'))
            ..createSync(recursive: true);
          final rootUri = Uri.directory(sampleDestDir.path).toString();
          File(p.join(dartTool.path, 'package_config.json')).writeAsStringSync(
            jsonEncode(<String, Object?>{
              'configVersion': 2,
              'packages': <Map<String, Object?>>[
                <String, Object?>{
                  'name': packageName,
                  'rootUri': rootUri,
                  'packageUri': 'lib/',
                  'languageVersion': '3.0',
                },
              ],
            }),
          );
        }

        final runner = AnalysisRunner(
          registry: _buildCliRegistry(),
          options: AnalOptions(
            includePaths: List<String>.unmodifiable(destIncludePaths),
            excludePaths: const <String>[],
            enabledRuleIds: const <String>{},
          ),
        );

        final diagnostics = await runner.run();

        final internal = diagnostics
            .where((d) => d.ruleId == '_internal')
            .toList();
        expect(
          internal,
          isEmpty,
          reason:
              'unexpected _internal errors for $sampleName: '
              '${internal.map((d) => d.message).toList()}',
        );

        final actual = <(String, String)>[
          for (final diagnostic in diagnostics)
            (
              diagnostic.ruleId,
              _toPosix(
                p.relative(
                  diagnostic.location.filePath,
                  from: sampleDestDir.path,
                ),
              ),
            ),
        ];

        int comparePair((String, String) a, (String, String) b) {
          final byRule = a.$1.compareTo(b.$1);
          if (byRule != 0) return byRule;
          return a.$2.compareTo(b.$2);
        }

        final sortedActual = [...actual]..sort(comparePair);
        final sortedExpected = [...expected]..sort(comparePair);

        expect(sortedActual, sortedExpected);
      });
    }
  });
}

String _toPosix(String path) => path.replaceAll(r'\', '/');
