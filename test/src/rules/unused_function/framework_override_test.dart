import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule framework-override exemption', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_framework_override_test_',
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    /// Runs the rule over [files]. Every entry is written to disk so it can
    /// be resolved, but only the keys listed in [analyzedKeys] are treated as
    /// part of the analyzed unit set (their resolved units are passed to the
    /// rule and their paths populate `analyzedFilePaths`). Files outside
    /// [analyzedKeys] stand in for code declared in another package — e.g.
    /// `package:flutter` — that the rule resolves through but never reports
    /// on and whose reference sites it cannot see.
    Future<List<Diagnostic>> runRule(
      Map<String, String> files, {
      required Set<String> analyzedKeys,
    }) async {
      final allPaths = <String>[];
      final analyzedPaths = <String>[];
      for (final entry in files.entries) {
        final file = File(p.join(tempDir.path, entry.key));
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(entry.value);
        final path = p.normalize(p.absolute(file.path));
        allPaths.add(path);
        if (analyzedKeys.contains(entry.key)) analyzedPaths.add(path);
      }

      final collection = AnalysisContextCollection(
        includedPaths: allPaths,
        sdkPath: _resolveSdkPath(),
      );

      final units = <ResolvedUnitResult>[];
      for (final path in analyzedPaths) {
        final session = collection.contextFor(path).currentSession;
        final result = await session.getResolvedUnit(path);
        expect(result, isA<ResolvedUnitResult>());
        units.add(result as ResolvedUnitResult);
      }

      final context = MultiFileAnalysisContext(
        units: units,
        analyzedFilePaths: <String>{for (final u in units) u.path},
      );
      return const UnusedFunctionRule().analyze(context).toList();
    }

    test('does not flag an instance method overriding a supertype member '
        'declared outside the analyzed set, even without @override', () async {
      final diagnostics = await runRule(
        {
          // Stand-in for package:flutter — resolved but not analyzed.
          'framework.dart': '''
abstract class Widget {
  State createState();
}
abstract class State {}
''',
          p.join('lib', 'src', 'my_widget.dart'): '''
import '../../framework.dart';
class MyWidget extends Widget {
  // Intentionally written WITHOUT an @override annotation, mirroring
  // real Flutter widgets whose createState lacks the annotation.
  State createState() => _MyState();
}
class _MyState extends State {}
''',
        },
        analyzedKeys: {p.join('lib', 'src', 'my_widget.dart')},
      );
      expect(diagnostics, isEmpty);
    });

    test('does not flag a getter overriding a supertype getter declared '
        'outside the analyzed set, even without @override', () async {
      final diagnostics = await runRule(
        {
          'framework.dart': '''
abstract class Base {
  int get value;
}
''',
          p.join('lib', 'src', 'impl.dart'): '''
import '../../framework.dart';
class Impl extends Base {
  int get value => 0;
}
''',
        },
        analyzedKeys: {p.join('lib', 'src', 'impl.dart')},
      );
      expect(diagnostics, isEmpty);
    });

    test(
      'still flags a method that does not override any supertype member',
      () async {
        final diagnostics = await runRule(
          {
            'framework.dart': '''
abstract class Widget {
  State createState();
}
abstract class State {}
''',
            p.join('lib', 'src', 'my_widget.dart'): '''
import '../../framework.dart';
class MyWidget extends Widget {
  State createState() => _MyState();
  // Does not override anything on Widget — must still be flagged.
  void helper() {}
}
class _MyState extends State {}
''',
          },
          analyzedKeys: {p.join('lib', 'src', 'my_widget.dart')},
        );
        expect(diagnostics, hasLength(1));
        final diagnostic = diagnostics.single;
        expect(diagnostic.ruleId, 'unused_function');
        expect(diagnostic.message, contains('helper'));
      },
    );
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
