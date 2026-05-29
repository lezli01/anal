import 'diagnostic.dart';
import 'rules/unused_class_rule.dart';
import 'rules/unused_function_rule.dart';
import 'rules/unused_source_file_rule.dart';

/// Drops [Diagnostic]s that are *nested inside* a file the
/// `unused_source_file` rule already reported as a whole, so a dead source
/// file produces a single file-level finding instead of also accruing a
/// per-declaration pile of `unused_class` / `unused_function` warnings for
/// everything declared in it.
///
/// ### The suppression hierarchy
///
/// The three "unused" rules form a containment hierarchy — a source file
/// contains types, a type contains members:
///
/// ```
/// unused_source_file   (whole file)
///   └── unused_class    (whole type)
///         └── unused_function   (member / constructor)
/// ```
///
/// When a finding at an outer level fires, re-reporting the levels nested
/// within it is pure noise: the consumer already knows the whole file (or
/// the whole type) is unused, so listing each of its declarations adds
/// nothing actionable. This function enforces the **file → {class,
/// function}** tier of that hierarchy.
///
/// The inner **class → member** tier is enforced earlier, inside
/// [UnusedFunctionRule] itself (it skips a member candidate whose enclosing
/// type is a private, unreferenced declaration that `unused_class` would
/// flag), because deciding whether a member belongs to a flagged type needs
/// the element model, not just the emitted [Diagnostic]s. This function
/// only needs each diagnostic's [SourceLocation.filePath], which is enough
/// for the file-level tier and keeps the runner decoupled from rule
/// internals.
///
/// ### Behavior
///
/// * Collects the set of file paths flagged by `unused_source_file` from
///   the already-emitted [diagnostics].
/// * Removes every `unused_class` and `unused_function` diagnostic whose
///   [SourceLocation.filePath] is in that set.
/// * Leaves everything else — the `unused_source_file` diagnostics
///   themselves, `_internal` errors, and any other rule's output —
///   untouched, and preserves the relative order of the survivors.
///
/// When no file is flagged by `unused_source_file` (the rule was disabled,
/// or every file is reachable) the input list is returned unchanged, so the
/// pass is a no-op in the common case. Keying off the *emitted*
/// `unused_source_file` diagnostics — rather than recomputing reachability —
/// guarantees the suppressor and the file-level rule never disagree about
/// which files are dead.
///
/// All three rules build [SourceLocation.filePath] from the same
/// absolute, normalized path the runner resolves each unit with, so a set
/// membership test reliably matches a file-level finding against the
/// per-declaration findings inside the same file.
List<Diagnostic> suppressFindingsInUnusedSourceFiles(
  List<Diagnostic> diagnostics,
) {
  final unusedFiles = <String>{
    for (final diagnostic in diagnostics)
      if (diagnostic.ruleId == _unusedSourceFileRuleId)
        diagnostic.location.filePath,
  };
  if (unusedFiles.isEmpty) return diagnostics;

  return <Diagnostic>[
    for (final diagnostic in diagnostics)
      if (!_isSuppressedInsideUnusedFile(diagnostic, unusedFiles)) diagnostic,
  ];
}

/// Whether [diagnostic] is a per-declaration finding nested inside a file
/// that `unused_source_file` already flagged in [unusedFiles].
bool _isSuppressedInsideUnusedFile(
  Diagnostic diagnostic,
  Set<String> unusedFiles,
) {
  final ruleId = diagnostic.ruleId;
  if (ruleId != _unusedClassRuleId && ruleId != _unusedFunctionRuleId) {
    return false;
  }
  return unusedFiles.contains(diagnostic.location.filePath);
}

/// Rule ids the suppressor reasons about, read from the rule classes
/// themselves so the cross-rule contract cannot silently drift if an id is
/// ever renamed.
final String _unusedSourceFileRuleId = const UnusedSourceFileRule().id;
final String _unusedClassRuleId = const UnusedClassRule().id;
final String _unusedFunctionRuleId = const UnusedFunctionRule().id;
