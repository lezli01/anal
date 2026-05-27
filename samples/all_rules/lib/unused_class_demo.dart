// Positive + negative cases for the `unused_class` rule.
//
// This file sits directly under `lib/`, so the `unused_source_file` rule
// treats it as an entry point and MUST NOT flag it. The library declares
// no `part` files, which is what makes its private top-level type
// declarations eligible candidates for `unused_class`.
//
// ignore_for_file: unused_element
library;

void main() {
  // (N1) Constructor invocation references `_UsedPrivateClass`. The
  // `unused_class` rule sees the reference and does NOT flag it.
  _UsedPrivateClass();
}

// === POSITIVE CASE (MUST trigger unused_class) ===

// (P1) Unused private top-level class. Nothing in this unit references
// `_UnusedPrivateClass`, so the rule flags it.
class _UnusedPrivateClass {}

// === NEGATIVE CASE (MUST NOT trigger unused_class) ===

class _UsedPrivateClass {}
