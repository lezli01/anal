// Entry point for the combined `all_rules` sample.
//
// This file sits directly under `lib/`, so the `unused_source_file` rule
// classifies it as an entry point. It imports `lib/src/used.dart`, which
// makes that file reachable. The companion `lib/src/orphan.dart` is
// intentionally NOT imported anywhere, so it is the positive case for
// `unused_source_file`.
library;

import 'src/used.dart';

/// Returns a greeting for [name], delegating to the imported helper.
String greet(String name) => hello(name);
