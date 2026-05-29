/// Positive case: nothing imports, exports, or `part`s this file, so the
/// `unused_source_file` rule MUST flag it when the sample is analyzed.
///
/// It deliberately also declares a private top-level function and a private
/// class. In a *reachable* file those would be flagged by `unused_function`
/// and `unused_class` respectively, but because the whole file is already
/// reported by `unused_source_file`, those nested findings are suppressed:
/// a dead source file is reported exactly once, not once per declaration
/// inside it. The sample test asserts this file produces a single
/// `unused_source_file` diagnostic and nothing else.
const String orphanGreeting = 'Goodbye';

/// Would be an `unused_function` positive in a reachable file; suppressed
/// here because the enclosing file is already flagged.
void _unusedOrphanHelper() {}

/// Would be an `unused_class` positive in a reachable file; suppressed here
/// because the enclosing file is already flagged.
class _UnusedOrphanHelper {}
