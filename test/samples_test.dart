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
  // samples/unused_function: README documents thirteen unused_function
  // diagnostics — one in lib/src/internals.dart (P11) and twelve in
  // lib/unused_function_sample.dart (P1..P10 plus P12, the override-of-
  // unreferenced-supertype-member positive case, plus P13, the
  // noSuchMethod-walk positive control on NoSuchMethodTarget.foo). The
  // sample also covers the generic-member identity normalisation
  // through the N17 / N18 negative cases (`Box<T>.put` / `Box<T>.peek`
  // called through `IntBox`, and `Holder<int>.value(0)` invoking a
  // generic sealed-class factory) — both MUST NOT be flagged because
  // candidate and reference elements are projected to their declared
  // base form. N19 exercises super-parameter forwarding (`class B
  // extends A { const B({super.x}); }` plus `const B(x: 1)`): the
  // implicit super-constructor invocation is recorded as a use of
  // `A.new`, so `A`'s constructor MUST NOT be flagged. N20 exercises
  // parameterised enums (`enum Route { home('/'), settings('/settings');
  // const Route(this.path); final String path; }` plus a read of
  // `Route.home.path`): each enum-value declaration invokes the enum's
  // constructor through `EnumConstantDeclaration.constructorElement`,
  // which the rule's `visitEnumConstantDeclaration` hook records as a
  // use — so `Route`'s constructor MUST NOT be flagged. N22 exercises
  // the freezed exemption: `@freezed`-annotated `FreezedSample` in
  // lib/src/internals.dart declares a private generative `_()` plus
  // unnamed and named factory constructors that are never referenced.
  // The rule recognises the freezed-related annotations on the
  // enclosing class and skips every constructor candidate, so none of
  // those constructors contribute a diagnostic. The constructor-
  // invocation form (`@Freezed()`) is covered by the rule's unit tests
  // rather than here. The companion
  // lib/src/l10n/l10n.dart and lib/src/l10n/l10n_en.dart mock the
  // output of `flutter gen-l10n` and are stamped with the de-facto
  // generated-code marker `// ignore_for_file: type=lint`; every
  // candidate in those units is exempt from the rule, so they MUST
  // NOT contribute any diagnostics.
  'unused_function': [
    ('unused_function', 'lib/src/internals.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
    ('unused_function', 'lib/unused_function_sample.dart'),
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
  // diagnostic pointing at lib/src/orphan.dart. The other lib/src files
  // (used.dart, used_via_part.dart, conditional_hub.dart, _io_impl.dart,
  // _web_impl.dart, deferred_target.dart) are negative cases — reached via
  // ordinary import, `part`, every `if (...)` configuration of a conditional
  // import, and a deferred import respectively — and must NOT be flagged.
  'unused_source_file': [('unused_source_file', 'lib/src/orphan.dart')],
  // samples/all_rules: README documents eighteen diagnostics across all three
  // built-in rules — thirteen unused_function (P11 in lib/src/internals.dart and
  // P1..P10 plus the override-of-unreferenced-supertype P12 and the
  // noSuchMethod-walk positive control P13 in
  // lib/unused_function_demo.dart), four unused_class (P1..P4 in
  // lib/unused_class_demo.dart), and one unused_source_file (lib/src/orphan.dart).
  // The combined sample also exercises the per-rule feature-aware negative cases:
  // object patterns, record literals + record patterns, cascades, callable-object
  // `.call`, the `noSuchMethod` / `dart:mirrors` exemptions, the
  // generic-member identity normalisation (calls into `Box<T>` through a
  // non-generic subtype and a generic sealed-class factory),
  // super-parameter forwarding (`class B extends A { const B({super.x}); }`
  // plus `const B(x: 1)` — the implicit super-constructor invocation
  // keeps `A.new` referenced), parameterised enums (`enum Route {
  // home('/'), settings('/settings'); const Route(this.path); final String
  // path; }` plus a read of `Route.home.path` — each enum-value declaration
  // invokes `Route`'s constructor through
  // `EnumConstantDeclaration.constructorElement`), the freezed
  // exemption (N22: `@freezed`-annotated `FreezedSample` in
  // lib/src/internals.dart — every constructor of a freezed-annotated
  // class is skipped because `package:freezed`'s code generator drives
  // those constructors from generated `*.freezed.dart` parts that are
  // typically absent when the rule runs), and the
  // `// ignore_for_file: type=lint` generated-code marker exemption for
  // unused_function (lib/unused_function_demo.dart, lib/src/mirrors_user.dart, and
  // lib/src/l10n/l10n.dart + lib/src/l10n/l10n_en.dart); object patterns,
  // record type annotations, and sealed-class pattern matching for unused_class
  // (lib/unused_class_demo.dart); and conditional + deferred imports for
  // unused_source_file (lib/src/conditional_hub.dart, lib/src/_io_impl.dart,
  // lib/src/_web_impl.dart, lib/src/deferred_target.dart). All of those negative
  // cases must NOT be flagged.
  'all_rules': [
    ('unused_function', 'lib/src/internals.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_function', 'lib/unused_function_demo.dart'),
    ('unused_class', 'lib/unused_class_demo.dart'),
    ('unused_class', 'lib/unused_class_demo.dart'),
    ('unused_class', 'lib/unused_class_demo.dart'),
    ('unused_class', 'lib/unused_class_demo.dart'),
    ('unused_source_file', 'lib/src/orphan.dart'),
  ],
};

/// Directories (relative to each sample root) that must be analyzed when
/// running the sample. Mirrors the invocation in each sample's README.
const Map<String, List<String>> _sampleIncludeDirs = {
  'unused_function': ['lib'],
  'unused_class': ['lib'],
  'unused_source_file': ['lib', 'bin'],
  'all_rules': ['lib', 'bin'],
};

/// Exclude globs to pass to the runner for each sample. Mirrors the
/// `--exclude` flag in each sample's README invocation. Samples not in the
/// map default to `const <String>[]` (no excludes). Samples present here
/// exercise the excluded-files-as-references behavior: excluded paths are
/// filtered out of the *reportable* set, but the frame still parses them
/// so their references flow into the cross-file rules' graphs.
const Map<String, List<String>> _sampleExcludePaths = {
  'unused_function': ['*.g.dart'],
  'unused_source_file': ['*.g.dart'],
  'all_rules': ['*.g.dart'],
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
  registry.registerMultiFile(UnusedFunctionRule());
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
            excludePaths: List<String>.unmodifiable(
              _sampleExcludePaths[sampleName] ?? const <String>[],
            ),
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
