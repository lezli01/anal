---
name: anal-probe
description: Probe all sample projects in the anal Dart package by running anal directly against each sample and verifying findings match expectations. Use whenever you want to validate the sample projects, check that a rule change doesn't break sample coverage, confirm anal runs cleanly against its own samples, or spot unexpected or missing diagnostics in any sample.
---

# anal-probe

Run `anal` directly on every sample project under `samples/` and verify each one emits **exactly** the expected diagnostics — no extras, no missing entries, no `_internal` errors.

## Prerequisites

You must be in (or navigate to) the `anal` repository root before running any command. The root is the directory that contains `pubspec.yaml` with `name: anal`.

```sh
# Confirm location
grep -m1 'name: anal' pubspec.yaml
```

If that fails, `cd` to the repo root first.

## Step 1 — Authoritative comparison via the test suite

Run the samples test directly. This is the canonical check: it copies each sample to a temp directory, runs analysis programmatically, and asserts the `(ruleId, relativePath)` pairs match the fixture exactly.

```sh
fvm flutter test test/samples_test.dart --reporter=expanded 2>&1
```

Capture the full output. Note which samples pass and which fail. A failing sample test already tells you exactly what was unexpected or missing.

## Step 2 — Run anal directly on each sample

Run `anal` from the repo root, passing the correct include directories for each sample. This gives you the raw human-readable output that matches what a consumer would see.

| Sample               | Command (from repo root)                                                    |
|----------------------|-----------------------------------------------------------------------------|
| `unused_function`    | `fvm dart run anal samples/unused_function/lib`                             |
| `unused_class`       | `fvm dart run anal samples/unused_class/lib`                                |
| `unused_source_file` | `fvm dart run anal samples/unused_source_file/lib samples/unused_source_file/bin` |
| `all_rules`          | `fvm dart run anal samples/all_rules/lib samples/all_rules/bin`             |

Run all four (in parallel if subagents are available, otherwise sequentially) and capture each output.

If a sample's `.dart_tool/package_config.json` is missing, run `fvm dart pub get --directory samples/<name>` first, then re-run anal on it.

## Step 3 — Check for `_internal` diagnostics

Scan each anal output for lines containing `_internal`. These indicate a rule implementation bug — a panic, uncaught exception, or unhandled edge case inside the rule itself. They count as failures even if the test suite somehow passes.

```sh
# Quick check across all sample outputs
echo "<combined output>" | grep '_internal'
```

## Step 4 — Report results

For each sample, report:
- **PASS ✓** or **FAIL ✗**
- Finding count (number of diagnostic lines in anal output)
- The raw anal output (all diagnostic lines, or "no findings" if clean)
- On failure: what was unexpected (extra lines) and what was missing (absent expected lines)

### Output format

```
## anal-probe results

### samples/unused_function — ✓ PASS  (11 findings)
lib/src/internals.dart:15:6 • [warning] unused_function: …
lib/unused_function_sample.dart:… (×10)
…

### samples/unused_class — ✓ PASS  (4 findings)
…

### samples/unused_source_file — ✓ PASS  (1 finding)
…

### samples/all_rules — ✗ FAIL  (expected 16, got 14)
Unexpected: (none)
Missing:
  unused_function  lib/unused_function_demo.dart
  unused_source_file  lib/src/orphan.dart
Raw output:
  …

---
3/4 samples pass.  1 failure — see all_rules above.
```

If everything passes, end with: `All N samples pass.`

## Failure guidance

| Symptom | Likely cause |
|---------|-------------|
| Extra finding(s) | A negative case in the sample now triggers the rule — update the sample source or the rule. |
| Missing finding(s) | A positive case in the sample no longer triggers — the rule regressed or the sample source drifted. |
| `_internal` diagnostic | Unhandled exception inside a rule; file a bug and fix the rule before merging. |
| Test suite passes but direct run differs | Path or package_config mismatch between the test harness and the direct invocation; check `_samplePackageNames` in `test/samples_test.dart`. |
| `pub get` needed | Run `fvm dart pub get --directory samples/<name>` and retry. |

## Adding a new sample

If `samples/` contains a directory not yet in the expected-diagnostics fixture (`_expectedDiagnostics` in `test/samples_test.dart`), flag it as **unvalidated**: run anal on it, show the output, and note that `test/samples_test.dart` must be updated to include it before it counts as validated.
