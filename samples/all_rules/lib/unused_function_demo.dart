// Positive + negative cases for the `unused_function` rule.
//
// This file sits directly under `lib/`, so the `unused_source_file` rule
// treats it as an entry point and MUST NOT flag it. The library declares
// no `part` files, which is what makes its private top-level functions
// eligible candidates for `unused_function`.
//
// ignore_for_file: unused_element
library;

// === POSITIVE CASE (MUST trigger unused_function) ===

// (P1) Unused private top-level function. The library has no part files and
// no reference to `_unusedPrivateTopLevel` exists in this unit, so the rule
// flags it.
void _unusedPrivateTopLevel() {}

// === NEGATIVE CASE (MUST NOT trigger unused_function) ===

void main() {
  // (N1) Private top-level function referenced from `main` — the rule sees
  // the reference and does NOT flag it.
  _usedPrivateTopLevel();
}

void _usedPrivateTopLevel() {}
