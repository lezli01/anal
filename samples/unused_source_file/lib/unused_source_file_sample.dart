/// Public surface of the sample.
///
/// This file sits directly under `lib/`, so the `unused_source_file` rule
/// classifies it as an entry point regardless of whether anything else
/// imports it. It pulls in `lib/src/used.dart`, which in turn declares
/// `lib/src/used_via_part.dart` as a `part`. Both should therefore be
/// reachable and must NOT be flagged.
library;

import 'src/used.dart';

/// Returns a greeting for [name], delegating to the chained library.
String greet(String name) => greeting(name);
