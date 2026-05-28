// Target of a deferred import from `conditional_hub.dart`. Deferred imports
// (`import 'x' deferred as p`) contribute the same reachability edge as
// ordinary imports, so this file is reachable through the hub and must NOT
// be flagged by the `unused_source_file` rule.

/// Value pulled in via a deferred import.
const String deferredValue = 'deferred';
