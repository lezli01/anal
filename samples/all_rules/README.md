# `all_rules` sample

A self-contained Dart/Flutter package that exercises **every** built-in rule
shipped by the [`anal`](../..) package in a single project — one positive and
one negative case per rule.

The sample exists so consumers (and the rules' own contributors) can see all
three rules co-firing on a real `pub get`-resolved tree, and so the reporter's
output for a mixed run is easy to eyeball.

## Layout

```
samples/all_rules/
  pubspec.yaml                       # path-dependent on the root `anal` package
  lib/
    all_rules_sample.dart            # lib/<package>.dart entry point
    unused_function_demo.dart        # positive + negative for unused_function
    unused_class_demo.dart           # positive + negative for unused_class
    src/
      used.dart                      # imported by the entry — reachable
      orphan.dart                    # never imported — UNREACHABLE
```

## Run it

From the repository root:

```sh
fvm dart pub get --directory samples/all_rules
fvm dart run anal samples/all_rules
```

## Expected output

Exactly three diagnostics — one per built-in rule — and nothing else:

```
samples/all_rules/lib/src/orphan.dart:1:1 • [warning] unused_source_file: The source file "samples/all_rules/lib/src/orphan.dart" is never imported, exported, or used as a part.
samples/all_rules/lib/unused_class_demo.dart:21:7 • [warning] unused_class: The class "_UnusedPrivateClass" is declared but never used.
samples/all_rules/lib/unused_function_demo.dart:16:6 • [warning] unused_function: The top-level function "_unusedPrivateTopLevel" is declared but never used.
```

(Diagnostic ordering depends on the runner's file iteration; the set of
`(file, ruleId)` pairs above is what's deterministic.)

### Positive cases (MUST be flagged)

| File                                              | Rule                 | Subject                                                                                  |
| ------------------------------------------------- | -------------------- | ---------------------------------------------------------------------------------------- |
| `lib/unused_function_demo.dart`                   | `unused_function`    | `_unusedPrivateTopLevel` — private top-level function with no reference in the unit.     |
| `lib/unused_class_demo.dart`                      | `unused_class`       | `_UnusedPrivateClass` — private top-level class with no reference in the unit.           |
| `lib/src/orphan.dart`                             | `unused_source_file` | the file itself — never imported, exported, or used as a `part` from any entry point.    |

### Negative cases (MUST NOT be flagged)

| File                                              | Rule                 | Why the rule skips it                                                                    |
| ------------------------------------------------- | -------------------- | ---------------------------------------------------------------------------------------- |
| `lib/unused_function_demo.dart`                   | `unused_function`    | `_usedPrivateTopLevel` is called from `main` in the same unit.                           |
| `lib/unused_class_demo.dart`                      | `unused_class`       | `_UsedPrivateClass` is invoked from `main` in the same unit.                             |
| `lib/src/used.dart`                               | `unused_source_file` | imported by `lib/all_rules_sample.dart` (a `lib/` direct-child entry point).             |
| `lib/all_rules_sample.dart`                       | `unused_source_file` | sits directly under `lib/`, so the rule treats it as an entry point.                     |
| `lib/unused_function_demo.dart`                   | `unused_source_file` | sits directly under `lib/`, so the rule treats it as an entry point.                     |
| `lib/unused_class_demo.dart`                      | `unused_source_file` | sits directly under `lib/`, so the rule treats it as an entry point.                     |
