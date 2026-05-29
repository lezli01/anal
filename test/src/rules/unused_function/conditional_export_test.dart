import 'dart:io';

import 'package:anal/src/diagnostic.dart';
import 'package:anal/src/multi_file_analysis_context.dart';
import 'package:anal/src/rules/unused_function_rule.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('UnusedFunctionRule conditional export/import branch targets', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync(
        'unused_function_conditional_export_test_',
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
        analyzedFilePaths: <String>{for (final u in units) u.path},
      );
      return const UnusedFunctionRule().analyze(context).toList();
    }

    test('does not flag members or top-level declarations in a '
        'conditional-export branch file', () async {
      final diagnostics = await runRule({
        p.join('lib', 'src', 'payment_service.dart'):
            "export 'payment_service_io.dart'\n"
            "    if (dart.library.html) 'payment_service_web.dart';\n",
        p.join('lib', 'src', 'payment_service_io.dart'):
            'class PaymentService {}\n',
        p.join('lib', 'src', 'payment_service_web.dart'):
            'class PaymentService {\n'
            '  void startMobileCheckout() {}\n'
            "  String get monthlyFeeText => '';\n"
            '}\n'
            '\n'
            'void saveAttribution() {}\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('does not flag declarations in a conditional-import branch '
        'file', () async {
      final diagnostics = await runRule({
        p.join('lib', 'src', 'consumer.dart'):
            "import 'install_view_io.dart'\n"
            "    if (dart.library.html) 'install_view_web.dart';\n",
        p.join('lib', 'src', 'install_view_io.dart'): 'class InstallView {}\n',
        p.join('lib', 'src', 'install_view_web.dart'):
            'class InstallView {\n'
            '  void onlyWeb() {}\n'
            '}\n'
            '\n'
            'void onlyWebHelper() {}\n',
      });
      expect(diagnostics, isEmpty);
    });

    test('still flags an unreferenced declaration in a file that is not a '
        'conditional branch target', () async {
      final diagnostics = await runRule({
        p.join('lib', 'src', 'plain.dart'): 'void unusedHelper() {}\n',
      });
      expect(diagnostics, hasLength(1));
      expect(diagnostics.single.message, contains('unusedHelper'));
    });

    test('exempts a conditional branch file even when the same declaration '
        'would otherwise be flagged elsewhere', () async {
      final diagnostics = await runRule({
        p.join('lib', 'src', 'attribution.dart'):
            "export 'attribution_io.dart'\n"
            "    if (dart.library.html) 'attribution_web.dart';\n",
        p.join('lib', 'src', 'attribution_io.dart'): 'class Attribution {}\n',
        p.join('lib', 'src', 'attribution_web.dart'):
            'class Attribution {\n'
            '  void saveAttribution() {}\n'
            '  void loadAttribution() {}\n'
            '}\n',
        // A plain (non-branch) file with an identically-named, unused
        // member is still flagged — proving the exemption is scoped to
        // branch-target files, not member names.
        p.join('lib', 'src', 'other.dart'): 'void saveAttribution() {}\n',
      });
      expect(diagnostics, hasLength(1));
      expect(
        diagnostics.single.location.filePath,
        p.normalize(
          p.absolute(p.join(tempDir.path, 'lib', 'src', 'other.dart')),
        ),
      );
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
