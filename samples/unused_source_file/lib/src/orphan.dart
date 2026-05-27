/// Positive case: nothing imports, exports, or `part`s this file, so the
/// `unused_source_file` rule MUST flag it when the sample is analyzed.
String orphanGreeting(String name) => 'Goodbye, $name';
