// Positive case for the `unused_source_file` rule.
//
// Nothing in the sample imports, exports, or `part`s this file, so the rule
// MUST flag it. The diagnostic is anchored at offset 0, line 1, column 1.
//
// Declared as a `const` rather than a function so the `unused_function`
// rule's public-top-level mode does not also flag it — `lib/unused_function_demo.dart`
// already owns the `unused_function` positive case for this combined sample.

/// Public helper that is intentionally never wired into the sample.
const String goodbyeGreeting = 'Goodbye';
