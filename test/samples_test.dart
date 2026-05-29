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
  // samples/unused_function: six unused_function diagnostics — one public
  // top-level in lib/src/internals.dart (`unusedPublicTopLevel`, P11, a
  // candidate because `lib/src/` is the package's internal surface) and
  // five in lib/unused_function_sample.dart: the private top-level
  // function `_unusedPrivateTopLevel` (P1), the private top-level getter
  // `_unusedTopLevelGetter` (P2) and setter `_unusedTopLevelSetter` (P3),
  // the private method `_unusedPrivateMethod` (P4), and the unused local
  // function `unusedLocal` (P9).
  //
  // The remaining public-API positives the sample once flagged are now
  // exempt: the unused static method/getter/setter/operator on the public
  // `Service` class (P5..P8), the public extension method (P10), the
  // override of an unreferenced supertype member on the public
  // `IsolatedSub` (P12), and the noSuchMethod-walk control on the public
  // `NoSuchMethodTarget.foo` (P13) all sit on a PUBLIC type declared
  // OUTSIDE `lib/src/`, so the rule treats them as package public API and
  // does not flag them ("no references in the analyzed set" cannot prove
  // a consumable member unused) — see the N24 negative case.
  //
  // The sample also covers the generic-member identity normalisation
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
  // use — so `Route`'s constructor MUST NOT be flagged. N22 covers the
  // conditional-export branch targets (lib/src/platform_export.dart plus
  // the IO/web impls): public members reachable only as an `if (...)`
  // configuration branch target are exempt. N23 covers an override of an
  // out-of-set supertype member without `@override` (`LifecycleHost
  // .toString` in lib/src/framework_overrides.dart overriding
  // `Object.toString`). N24 covers public members of a public type
  // declared outside `lib/src/` (`PublicSurface`, `PublicChannel`). N25
  // exercises the freezed exemption: `@freezed`-annotated `FreezedSample`
  // in lib/src/internals.dart declares constructors that are only invoked
  // from generated `*.freezed.dart` parts — the rule recognises the
  // freezed-related annotations and skips every constructor candidate. The
  // companion lib/src/l10n/l10n.dart and lib/src/l10n/l10n_en.dart mock
  // the output of `flutter gen-l10n` and are stamped with the de-facto
  // generated-code marker `// ignore_for_file: type=lint`; every
  // candidate in those units is exempt from the rule. None of these
  // negative cases contribute any diagnostics.
  'unused_function': [
    ('unused_function', 'lib/src/internals.dart'),
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
  // orphan.dart also declares a private function (`_unusedOrphanHelper`) and
  // a private class (`_UnusedOrphanHelper`); in a reachable file those would
  // be flagged by unused_function / unused_class, but because the whole file
  // is already reported by unused_source_file the nested findings are
  // suppressed — the single entry below (and the ABSENCE of any
  // unused_class/unused_function entry for orphan.dart) is the machine-checked
  // proof of that suppression.
  'unused_source_file': [('unused_source_file', 'lib/src/orphan.dart')],
  // samples/all_rules: eleven diagnostics across all three built-in rules —
  // six unused_function (P11 `unusedPublicTopLevel` in lib/src/internals.dart
  // and the five private/local positives P1..P4 plus P9 in
  // lib/unused_function_demo.dart), four unused_class (P1..P4 in
  // lib/unused_class_demo.dart), and one unused_source_file (lib/src/orphan.dart).
  // lib/src/orphan.dart additionally declares a private function and a private
  // class; both would be flagged in a reachable file but are suppressed here
  // because unused_source_file already reports the whole file, so the count
  // stays at eleven with NO unused_class/unused_function entry for orphan.dart.
  // As in samples/unused_function, the public-API positives P5..P8, P10, P12
  // and P13 are exempt because they sit on a public type declared outside
  // `lib/src/` (see the public-surface negative case below).
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
  // `EnumConstantDeclaration.constructorElement`), conditional-export
  // branch targets (N21: the non-selected `web_impl.dart` export branch,
  // whose public members are exempt), an override of an out-of-set
  // supertype member without `@override` (N22: `LifecycleHost.toString`
  // in lib/src/framework_overrides.dart), public members of a public type
  // declared outside `lib/src/` (N23: `PublicSurface`, `PublicChannel` in
  // lib/unused_function_demo.dart), the freezed exemption (N24:
  // `@freezed`-annotated `FreezedSample` in lib/src/internals.dart), and
  // the
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
