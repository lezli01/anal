/// Public surface of the sample.
///
/// This file sits directly under `lib/`, so the `unused_source_file` rule
/// classifies it as an entry point regardless of whether anything else
/// imports it. It pulls in `lib/src/used.dart`, which in turn declares
/// `lib/src/used_via_part.dart` as a `part`. Both should therefore be
/// reachable and must NOT be flagged.
///
/// It also pulls in `lib/src/conditional_hub.dart`, whose conditional and
/// deferred imports keep `_io_impl.dart`, `_web_impl.dart`, and
/// `deferred_target.dart` reachable on every platform.
library;

import 'src/conditional_hub.dart';
import 'src/used.dart';

// Conditional export: on the VM the analyzer's resolved URI points at
// `src/mobile_impl.dart`; under `dart.library.html` (Flutter web) it
// points at `src/web_impl.dart`. The `unused_source_file` rule must
// follow BOTH branches so neither impl file is flagged when the sample
// is analysed on a single platform.
export 'src/mobile_impl.dart' if (dart.library.html) 'src/web_impl.dart';

/// Returns a greeting for [name], delegating to the chained library.
String greet(String name) => greeting(name);

/// Exposes the hub so the conditional and deferred imports are exercised
/// when the sample is run as well as analyzed.
Future<String> conditional() => hub();
