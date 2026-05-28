// Hub file that wires conditional and deferred imports into the sample's
// reachability graph.
//
// The conditional import below names `_io_impl.dart` and `_web_impl.dart` in
// its `if (...)` configurations. The `unused_source_file` rule follows every
// configuration regardless of the active platform, so both implementation
// files are reachable here and must NOT be flagged.
//
// The deferred import (`deferred as deferred_lib`) is followed the same way
// an ordinary import would be, so `deferred_target.dart` is also reachable
// and must NOT be flagged.

import '_io_impl.dart'
    if (dart.library.io) '_io_impl.dart'
    if (dart.library.html) '_web_impl.dart';
import 'deferred_target.dart' deferred as deferred_lib;

/// Combines the active platform name with a deferred value, exercising both
/// the conditional and the deferred imports above.
Future<String> hub() async {
  await deferred_lib.loadLibrary();
  return '$platformName: ${deferred_lib.deferredValue}';
}
