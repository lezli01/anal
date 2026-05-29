// Positive case for the `unused_source_file` rule, and a negative case for
// the cross-rule nesting suppression.
//
// Nothing in the sample imports, exports, or `part`s this file, so
// `unused_source_file` MUST flag it. The diagnostic is anchored at offset 0,
// line 1, column 1.
//
// The file also declares a private top-level function and a private class.
// In a reachable file `unused_function` would flag `_unusedOrphanHelper` and
// `unused_class` would flag `_UnusedOrphanHelper`, but because the whole file
// is already reported by `unused_source_file`, those nested findings are
// suppressed — a dead source file is reported once, not once per declaration.

/// Public helper that is intentionally never wired into the sample.
const String goodbyeGreeting = 'Goodbye';

/// Suppressed `unused_function` positive: the enclosing file is already
/// flagged by `unused_source_file`.
void _unusedOrphanHelper() {}

/// Suppressed `unused_class` positive: the enclosing file is already flagged
/// by `unused_source_file`.
class _UnusedOrphanHelper {}
