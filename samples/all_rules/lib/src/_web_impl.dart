// Platform-specific implementation reached from `conditional_hub.dart` via
// the `if (dart.library.html)` configuration of a conditional import. The
// `unused_source_file` rule follows every configuration of a conditional
// import regardless of the active platform, so this file must NOT be
// flagged even on platforms where the analyzer would normally resolve a
// different configuration.
//
// Declared as a `const` rather than a function so the `unused_function`
// rule's public-top-level mode does not also flag it on the inactive
// platform — the sample is meant to demonstrate `unused_source_file`'s
// conditional-import handling, not double-flag with `unused_function`.

/// Platform name reported by the web implementation.
const String platformName = 'web';
