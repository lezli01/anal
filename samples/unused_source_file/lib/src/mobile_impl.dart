// Default (VM/mobile) branch of the conditional export declared in
// `lib/unused_source_file_sample.dart`. The entry point exports this file
// outright, so it is always reachable and must NOT be flagged.
//
// Declared as a `const` rather than a function so the `unused_function`
// rule's public-top-level mode does not also flag it — the negative case
// is meant to demonstrate `unused_source_file`'s handling of
// conditional-URI branches, not double-flag with `unused_function`.
const String platformLabel = 'mobile';
