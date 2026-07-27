/// Dart-side snapshot of a `gb_progress` struct, decoded off the FFI
/// boundary so callers never touch native memory directly.
class GbProgress {
  /// Creates an immutable snapshot of one progress event.
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

  /// Short human-readable status, e.g. "Receiving objects: 4/10".
  final String message;

  /// Bytes transferred so far over the network, when known.
  final int bytesReceived;

  /// Total objects libgit2 expects to process for this phase.
  final int totalObjects;

  /// Objects processed so far.
  final int receivedObjects;

  @override
  String toString() => 'GbProgress($percent% $message)';
}

/// Called on the isolate that invoked `Git2Bridge.clone`/`pull`/`push`
/// as each `gb_progress` event arrives.
typedef GbProgressCallback = void Function(GbProgress progress);
