/// Positive case: nothing imports, exports, or `part`s this file, so the
/// `unused_source_file` rule MUST flag it when the sample is analyzed.
///
/// Declared as a `const` rather than a function so the `unused_function`
/// rule's public-top-level mode does not also flag it — the sample is
/// meant to demonstrate `unused_source_file`, not double-flag with
/// `unused_function`.
const String orphanGreeting = 'Goodbye';
