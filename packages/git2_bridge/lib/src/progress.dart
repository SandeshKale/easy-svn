/// Dart-side snapshot of a `gb_progress` struct, decoded off the FFI
/// boundary so callers never touch native memory directly.
class GbProgress {
  const GbProgress({
    required this.percent,
    required this.message,
    required this.bytesReceived,
    required this.totalObjects,
    required this.receivedObjects,
  });

  /// 0-100, or -1 when the underlying libgit2 phase can't report a
  /// precise percentage (see git_bridge.h).
  final int percent;
  final String message;
  final int bytesReceived;
  final int totalObjects;
  final int receivedObjects;

  @override
  String toString() => 'GbProgress($percent% $message)';
}

typedef GbProgressCallback = void Function(GbProgress progress);
