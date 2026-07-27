/// Dart-side mirror of `gb_error_code` (native/include/git_bridge.h),
/// plus the user-facing copy for each — this is the "map libgit2
/// error codes to user-friendly messages" task from the plan (§4 W9).
enum GbErrorCode {
  ok(0, 'Success'),
  generic(-1, 'Something went wrong. Please try again.'),
  notFound(-3, 'Not found.'),
  exists(-4, 'Already exists.'),
  auth(-16, 'Authentication failed. Please sign in again.'),
  nonFastForward(
    -11,
    'The remote has changes that can\'t be fast-forwarded. '
    'Resolve this on a desktop client for now.',
  ),
  certificate(-17, 'Could not verify the server\'s certificate.'),
  uncommittedChanges(
    -20,
    'You have local changes that would be overwritten. '
    'Commit or discard them first.',
  ),
  conflict(-21, 'This change conflicts with another change.'),
  invalidSpec(-22, 'That operation isn\'t valid for this repository.'),
  network(100, 'Network error. Check your connection and try again.'),
  cancelled(101, 'Cancelled.'),
  noUpstream(102, 'This branch has no upstream to push to.'),
  unbornHead(103, 'This repository has no commits yet.');

  const GbErrorCode(this.code, this.userMessage);

  final int code;
  final String userMessage;

  static GbErrorCode fromCode(int code) {
    return GbErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => GbErrorCode.generic,
    );
  }
}

/// Thrown by [Git2Bridge] methods when the native call returns a
/// non-zero `gb_error_code`.
class GitBridgeException implements Exception {
  GitBridgeException(this.errorCode, this.nativeMessage);

  final GbErrorCode errorCode;

  /// Raw message from `gb_last_error_message()` (libgit2's own error
  /// text) — useful for logs/bug reports, not for direct display.
  final String nativeMessage;

  /// Short, user-facing message safe to show in the UI.
  String get userMessage => errorCode.userMessage;

  @override
  String toString() => 'GitBridgeException(${errorCode.name}): $nativeMessage';
}

void throwIfError(int code, String nativeMessage) {
  if (code == 0) return;
  throw GitBridgeException(GbErrorCode.fromCode(code), nativeMessage);
}
