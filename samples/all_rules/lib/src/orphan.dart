// Positive case for the `unused_source_file` rule.
//
// Nothing in the sample imports, exports, or `part`s this file, so the rule
// MUST flag it. The diagnostic is anchored at offset 0, line 1, column 1.

/// Public helper that is intentionally never wired into the sample.
String goodbye(String name) => 'Goodbye, $name';
