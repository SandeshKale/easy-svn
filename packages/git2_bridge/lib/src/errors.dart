/// Dart-side mirror of `gb_error_code` (native/include/git_bridge.h),
/// plus the user-facing copy for each — this is the "map libgit2
/// error codes to user-friendly messages" task from the plan (§4 W9).
enum GbErrorCode {
  /// The operation completed successfully; never thrown as an
  /// exception, only used internally by [throwIfError].
  ok(0, 'Success'),

  /// Catch-all for libgit2 errors this bridge doesn't map to a more
  /// specific code.
  generic(-1, 'Something went wrong. Please try again.'),

  /// The repository, ref, or path in question doesn't exist.
  notFound(-3, 'Not found.'),

  /// Attempted to create something (e.g. a local clone directory)
  /// that already exists.
  exists(-4, 'Already exists.'),

  /// HTTPS credentials were missing, expired, or rejected by the
  /// remote.
  auth(-16, 'Authentication failed. Please sign in again.'),

  /// `gb_pull` found the local and remote branches have diverged —
  /// out of scope for this MVP (plan §5.4: fast-forward only).
  nonFastForward(
    -11,
    "The remote has changes that can't be fast-forwarded. "
    'Resolve this on a desktop client for now.',
  ),

  /// The remote's TLS certificate could not be verified.
  certificate(-17, "Could not verify the server's certificate."),

  /// `gb_pull` refused to run because the working tree has local
  /// changes that would be overwritten by a fast-forward checkout.
  uncommittedChanges(
    -20,
    'You have local changes that would be overwritten. '
    'Commit or discard them first.',
  ),

  /// The requested change conflicts with existing repository state.
  conflict(-21, 'This change conflicts with another change.'),

  /// The requested operation doesn't apply to this repository's
  /// current state (e.g. pushing a non-branch HEAD).
  invalidSpec(-22, "That operation isn't valid for this repository."),

  /// A network-level failure occurred during fetch/push.
  network(100, 'Network error. Check your connection and try again.'),

  /// The operation was cancelled before completing.
  cancelled(101, 'Cancelled.'),

  /// `gb_push` found no upstream configured for the current branch.
  noUpstream(102, 'This branch has no upstream to push to.'),

  /// `gb_get_head_info` was called on a repository with no commits
  /// yet (an "unborn" HEAD) — distinct from [notFound], which means
  /// the repository itself doesn't exist.
  unbornHead(103, 'This repository has no commits yet.');

  const GbErrorCode(this.code, this.userMessage);

  /// The matching `gb_error_code` value from git_bridge.h.
  final int code;

  /// Short, user-facing message safe to show directly in the UI.
  final String userMessage;

  /// Maps a raw `gb_error_code` int (as returned by a native call) to
  /// its [GbErrorCode], falling back to [generic] for anything this
  /// bridge doesn't recognize.
  static GbErrorCode fromCode(int code) {
    return GbErrorCode.values.firstWhere(
      (e) => e.code == code,
      orElse: () => GbErrorCode.generic,
    );
  }
}

/// Thrown by `Git2Bridge` methods when the native call returns a
/// non-zero `gb_error_code`.
class GitBridgeException implements Exception {
  /// Creates an exception for a specific [errorCode], carrying the
  /// raw native error text in [nativeMessage].
  GitBridgeException(this.errorCode, this.nativeMessage);

  /// The mapped error code.
  final GbErrorCode errorCode;

  /// Raw message from `gb_last_error_message()` (libgit2's own error
  /// text) — useful for logs/bug reports, not for direct display.
  final String nativeMessage;

  /// Short, user-facing message safe to show in the UI.
  String get userMessage => errorCode.userMessage;

  @override
  String toString() => 'GitBridgeException(${errorCode.name}): $nativeMessage';
}

/// Throws a [GitBridgeException] if `code` is non-zero; otherwise
/// returns normally. Every `Git2Bridge` method funnels its native
/// call's return code through this.
void throwIfError(int code, String nativeMessage) {
  if (code == 0) return;
  throw GitBridgeException(GbErrorCode.fromCode(code), nativeMessage);
}
