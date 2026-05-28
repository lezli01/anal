import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_source_file_rule.dart';
import 'package:anal/src/severity.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedSourceFileRule', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_source_file_rule_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<List<Diagnostic>> runRule(Map<String, String> files) async {
      final paths = <String>[];
      for (final entry in files.entries) {
        final file = File(p.join(tempDir.path, entry.key));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
        paths.add(p.normalize(p.absolute(file.path)));
      }
      if (paths.isEmpty) {
        final context = MultiFileAnalysisContext(
          units: const <ResolvedUnitResult>[],
          analyzedFilePaths: const <String>{},
        );
        return const UnusedSourceFileRule().analyze(context).toList();
      }
      final collection = AnalysisContextCollection(
        includedPaths: paths,
        sdkPath: _resolveSdkPath(),
      );
      final units = <ResolvedUnitResult>[];
      for (final path in paths) {
        final session = collection.contextFor(path).currentSession;
        final result = await session.getResolvedUnit(path);
        expect(result, isA<ResolvedUnitResult>());
        units.add(result as ResolvedUnitResult);
      }
      final context = MultiFileAnalysisContext(
        units: units,
        analyzedFilePaths: paths.toSet(),
      );
      return const UnusedSourceFileRule().analyze(context).toList();
    }

    test('exposes the rule contract', () {
      const rule = UnusedSourceFileRule();
      expect(rule.id, 'unused_source_file');
      expect(rule.description, isNotEmpty);
      expect(rule.defaultSeverity, Severity.warning);
    });

    test('empty input emits nothing', () async {
      final diagnostics = await runRule(const <String, String>{});
      expect(diagnostics, isEmpty);
    });

    test('a fully-used graph emits nothing', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): "export 'src/foo.dart';\n",
        p.join('lib', 'src', 'foo.dart'):
            "import 'bar.dart';\nint useBar() => bar();\n",
        p.join('lib', 'src', 'bar.dart'): 'int bar() => 1;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('an orphan lib/src file is flagged', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): '// public surface\n',
        p.join('lib', 'src', 'orphan.dart'): 'int orphan() => 1;\n',
      });
      expect(diagnostics, hasLength(1));
      final diagnostic = diagnostics.single;
      expect(diagnostic.ruleId, 'unused_source_file');
      expect(diagnostic.severity, Severity.warning);
      expect(
        diagnostic.location.filePath,
        p.normalize(
          p.absolute(p.join(tempDir.path, 'lib', 'src', 'orphan.dart')),
        ),
      );
      expect(diagnostic.location.offset, 0);
      expect(diagnostic.location.length, 0);
      expect(diagnostic.location.line, 1);
      expect(diagnostic.location.column, 1);
      expect(diagnostic.message, contains('orphan.dart'));
      expect(
        diagnostic.message,
        contains('never imported, exported, or used as a part'),
      );
    });

    test('a file reached only via export is not flagged', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): "export 'src/exported.dart';\n",
        p.join('lib', 'src', 'exported.dart'): 'int answer() => 42;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('a file reached only via part is not flagged', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): "library pkg;\npart 'src/parted.dart';\n",
        p.join('lib', 'src', 'parted.dart'):
            "part of pkg;\nint partAnswer() => 7;\n",
      });
      expect(diagnostics, isEmpty);
    });

    test(
      'transitive reachability through a chain of imports is honored',
      () async {
        final diagnostics = await runRule({
          p.join('bin', 'tool.dart'):
              "import '../lib/src/a.dart';\nvoid main() { a(); }\n",
          p.join('lib', 'src', 'a.dart'): "import 'b.dart';\nint a() => b();\n",
          p.join('lib', 'src', 'b.dart'): "import 'c.dart';\nint b() => c();\n",
          p.join('lib', 'src', 'c.dart'): 'int c() => 1;\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'a bin/ entry point and a top-level main function are both treated as roots',
      () async {
        final diagnostics = await runRule({
          p.join(
            'bin',
            'tool.dart',
          ): "import '../lib/src/from_bin.dart';\nvoid main() { fromBin(); }\n",
          p.join('lib', 'src', 'from_bin.dart'): 'int fromBin() => 1;\n',
          // A loose file with a top-level main() should also be a root, even
          // though its path does not match bin/, test/, or lib/<file>.dart.
          p.join(
            'scripts',
            'oneoff.dart',
          ): "import '../lib/src/from_main.dart';\nvoid main() { fromMain(); }\n",
          p.join('lib', 'src', 'from_main.dart'): 'int fromMain() => 2;\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'lib/<package>.dart and other lib/*.dart files are treated as roots',
      () async {
        final diagnostics = await runRule({
          // The package root surface.
          p.join('lib', 'pkg.dart'): "export 'src/from_pkg.dart';\n",
          // Another top-level public file.
          p.join('lib', 'extras.dart'): "export 'src/from_extras.dart';\n",
          p.join('lib', 'src', 'from_pkg.dart'): 'int fromPkg() => 1;\n',
          p.join('lib', 'src', 'from_extras.dart'): 'int fromExtras() => 2;\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test('diagnostics are sorted by file path', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): '// public surface\n',
        p.join('lib', 'src', 'zeta.dart'): 'int zeta() => 1;\n',
        p.join('lib', 'src', 'alpha.dart'): 'int alpha() => 1;\n',
        p.join('lib', 'src', 'mid.dart'): 'int mid() => 1;\n',
      });
      expect(diagnostics, hasLength(3));
      final paths = diagnostics.map((d) => d.location.filePath).toList();
      final sorted = [...paths]..sort();
      expect(paths, sorted);
    });

    test('test/ files are treated as entry points', () async {
      final diagnostics = await runRule({
        p.join('test', 'foo_test.dart'):
            "import '../lib/src/foo.dart';\nvoid main() { foo(); }\n",
        p.join('lib', 'src', 'foo.dart'): 'int foo() => 1;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('a conditional export resolves both branches as reachable', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'):
            "export 'src/mobile_impl.dart'\n"
            "    if (dart.library.html) 'src/web_impl.dart';\n",
        p.join('lib', 'src', 'mobile_impl.dart'): 'int mobile() => 1;\n',
        p.join('lib', 'src', 'web_impl.dart'): 'int web() => 2;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('a conditional import resolves both branches as reachable', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'):
            "import 'src/mobile_impl.dart'\n"
            "    if (dart.library.html) 'src/web_impl.dart';\n"
            'int use() => mobile();\n',
        p.join('lib', 'src', 'mobile_impl.dart'): 'int mobile() => 1;\n',
        p.join('lib', 'src', 'web_impl.dart'): 'int web() => 2;\n',
      });
      expect(diagnostics, isEmpty);
    });

    test(
      'transitive reachability via a conditional branch is honored',
      () async {
        final diagnostics = await runRule({
          p.join('lib', 'pkg.dart'):
              "export 'src/mobile_impl.dart'\n"
              "    if (dart.library.html) 'src/web_impl.dart';\n",
          p.join('lib', 'src', 'mobile_impl.dart'): 'int mobile() => 1;\n',
          // The web branch is the *only* path that reaches `web_helper.dart`.
          // The web branch is inactive on the VM, but the rule must still
          // treat `web_helper.dart` as reachable so neither file is flagged.
          p.join('lib', 'src', 'web_impl.dart'):
              "import 'web_helper.dart';\nint web() => helper();\n",
          p.join('lib', 'src', 'web_helper.dart'): 'int helper() => 3;\n',
        });
        expect(diagnostics, isEmpty);
      },
    );

    test(
      'a file referenced only by a non-existent conditional URI is still flagged',
      () async {
        // `web_impl.dart` is mentioned only in a conditional branch whose
        // URI does not resolve to any file in the analyzed set (the import
        // points at a file that was deleted). It must therefore remain an
        // orphan and be flagged.
        final diagnostics = await runRule({
          p.join('lib', 'pkg.dart'):
              "export 'src/mobile_impl.dart'\n"
              "    if (dart.library.html) 'src/missing.dart';\n",
          p.join('lib', 'src', 'mobile_impl.dart'): 'int mobile() => 1;\n',
          p.join('lib', 'src', 'web_impl.dart'): 'int web() => 2;\n',
        });
        expect(diagnostics, hasLength(1));
        expect(
          diagnostics.single.location.filePath,
          p.normalize(
            p.absolute(p.join(tempDir.path, 'lib', 'src', 'web_impl.dart')),
          ),
        );
      },
    );

    test('generated-file basenames are skipped defensively', () async {
      final diagnostics = await runRule({
        p.join('lib', 'pkg.dart'): '// public surface\n',
        p.join('lib', 'src', 'thing.g.dart'): '// generated\n',
        p.join('lib', 'src', 'model.freezed.dart'): '// generated\n',
      });
      expect(diagnostics, isEmpty);
    });
  });
}

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
