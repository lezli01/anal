// Reachable from `lib/all_rules_sample.dart` via a direct import — the
// negative case for the `unused_source_file` rule. The rule MUST NOT flag
// this file.

/// Public helper used by the sample's entry point.
String hello(String name) => 'Hello, $name';
