// Web branch of the conditional export declared in
// `lib/all_rules_sample.dart`. Only the active branch (mobile, when
// analysed on the VM) is exposed by the analyzer's resolved URI, but
// `unused_source_file` follows every `Configuration` of the export so
// this file is still treated as reachable and must NOT be flagged.
//
// (unused_function N21) This file is also named in an
// `if (dart.library.html)` configuration of the export, so the
// `unused_function` rule treats the whole file as a conditional-export
// branch target and skips every candidate declared in it. The public
// top-level function and the public class members below sit under
// `lib/src/`, so they are NOT covered by the public-members-outside-
// `lib/src/` exemption — the conditional-export branch-target exemption
// is the only reason they are not flagged.
//
// ignore_for_file: unused_element
library;

const String platformLabel = 'web';

/// Platform label reported by the web implementation.
String platformLabelFn() => 'web';

/// Platform service exposed only through the web export branch.
class WebPlatformService {
  /// Starts the platform service.
  void start() {}

  /// Disposes the platform service.
  void dispose() {}
}
