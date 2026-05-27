/// A location inside a Dart source file.
///
/// All offsets and lengths use the same convention as `package:analyzer`:
/// [offset] and [length] are measured in UTF-16 code units and [offset] is
/// zero-based. [line] and [column] are one-based to match the format human
/// readers (and most editors) expect.
///
/// Instances are immutable and compare structurally by every field.
class SourceLocation {
  /// Absolute, normalized path to the source file.
  final String filePath;

  /// Zero-based offset into the file, in UTF-16 code units.
  final int offset;

  /// Length of the span at [offset], in UTF-16 code units.
  final int length;

  /// One-based line number where the span begins.
  final int line;

  /// One-based column number where the span begins.
  final int column;

  /// Creates a [SourceLocation].
  ///
  /// All fields are required and named so call sites read clearly at the
  /// rule-implementation layer.
  const SourceLocation({
    required this.filePath,
    required this.offset,
    required this.length,
    required this.line,
    required this.column,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SourceLocation &&
        other.filePath == filePath &&
        other.offset == offset &&
        other.length == length &&
        other.line == line &&
        other.column == column;
  }

  @override
  int get hashCode => Object.hash(filePath, offset, length, line, column);

  /// Returns a `file:line:column`-style string suitable for console reports.
  @override
  String toString() => '$filePath:$line:$column';
}
