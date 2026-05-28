// Web branch of the conditional export declared in
// `lib/unused_source_file_sample.dart`. Only the active branch (mobile,
// when analysed on the VM) is exposed by the analyzer's resolved URI, but
// `unused_source_file` follows every `Configuration` of the export so this
// file is still treated as reachable and must NOT be flagged.
//
// Declared as a `const` rather than a function so the `unused_function`
// rule's public-top-level mode does not also flag it — the negative case
// is meant to demonstrate `unused_source_file`'s handling of
// conditional-URI branches, not double-flag with `unused_function`.
const String platformLabel = 'web';
