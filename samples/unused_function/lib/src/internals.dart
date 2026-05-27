// Companion file to the unused_function sample's main entry point.
//
// Living under `lib/src/`, this file is treated by the rule as part of
// the package's *internal* surface — public top-level declarations
// here are candidates for `unused_function` and become positives when
// they go unreferenced. Files directly under `lib/` are skipped by
// contrast because they form the package's *public* surface.
//
// ignore_for_file: unused_element
library;

// (P11) Unused public top-level function in `lib/src/`. The rule treats
// `lib/src/` as the package's internal surface, so a public top-level
// function with no reference anywhere in the analyzed set is flagged.
void unusedPublicTopLevel() {}

// Used public top-level function — referenced from `main` in the
// sample's entry point, so the rule does not flag it.
void usedPublicTopLevel() {}
