/// High-level, isolate-safe Dart API over the native git bridge
/// (native/src/git_bridge.c). All operations run inside a fresh
/// background [Isolate] via [Isolate.run] — the calling isolate (the
/// Flutter UI isolate, typically) is never blocked (plan §5.2).
///
/// Long-running operations (clone/pull/push) accept an optional
/// [GbProgressCallback] that is invoked on the *calling* isolate as
/// native progress events arrive, using [NativeCallable.listener] —
/// this delivers real-time progress even though the worker isolate's
/// own event loop is blocked inside the native call for the whole
/// operation.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'src/errors.dart';
import 'src/git2_bridge_bindings_generated.dart';
import 'src/native_library.dart';
import 'src/progress.dart';

export 'src/errors.dart';
export 'src/progress.dart';

/// One file-status entry from `gb_get_status` (see git_bridge.h).
class GbStatusEntry {
  /// Creates a status entry directly; prefer [GbStatusEntry.fromJson]
  /// when decoding a `gb_get_status` response.
  const GbStatusEntry({
    required this.path,
    required this.status,
    required this.staged,
  });

  /// Decodes one element of the JSON array `gb_get_status` returns.
  factory GbStatusEntry.fromJson(Map<String, dynamic> json) => GbStatusEntry(
    path: json['path'] as String,
    status: json['status'] as String,
    staged: json['staged'] as bool,
  );

  /// Path relative to the repository root.
  final String path;

  /// One of: added, modified, deleted, renamed, typechange, conflicted.
  final String status;

  /// Whether this change is currently in the index (staged).
  final bool staged;
}

/// One entry from `gb_get_file_tree` (see git_bridge.h).
class GbTreeEntry {
  /// Creates a tree entry directly; prefer [GbTreeEntry.fromJson] when
  /// decoding a `gb_get_file_tree` response.
  const GbTreeEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
  });

  /// Decodes one element of the JSON array `gb_get_file_tree` returns.
  factory GbTreeEntry.fromJson(Map<String, dynamic> json) => GbTreeEntry(
    name: json['name'] as String,
    path: json['path'] as String,
    isDirectory: json['type'] == 'tree',
    size: json['size'] as int?,
  );

  /// The entry's own name, e.g. `README.md` (not the full path).
  final String name;

  /// Path relative to the repository root.
  final String path;

  /// `true` for a subdirectory (a git tree), `false` for a file (a
  /// git blob).
  final bool isDirectory;

  /// File size in bytes; `null` for directories.
  final int? size;
}

/// Result of `gb_get_head_info`.
class GbHeadInfo {
  /// Creates a HEAD summary directly; prefer [GbHeadInfo.fromJson]
  /// when decoding a `gb_get_head_info` response.
  const GbHeadInfo({
    required this.sha,
    required this.summary,
    required this.branch,
  });

  /// Decodes the JSON object `gb_get_head_info` returns.
  factory GbHeadInfo.fromJson(Map<String, dynamic> json) => GbHeadInfo(
    sha: json['sha'] as String,
    summary: json['summary'] as String,
    branch: json['branch'] as String,
  );

  /// Short commit SHA.
  final String sha;

  /// First line of the commit message.
  final String summary;

  /// Current branch name.
  final String branch;
}

/// Static entry points for every native git operation. Stateless by
/// design — all state lives in the on-disk repository (and in Drift,
/// one layer up); this class is just an isolate-safe FFI façade.
abstract final class Git2Bridge {
  /// Clones [url] into [path] (`gb_clone`). Pass [token] for HTTPS
  /// auth against private repos; omit it for anonymous clones of
  /// public ones. [shallow] performs a depth-1 clone (plan §5.3).
  static Future<void> clone({
    required String url,
    required String path,
    String? token,
    bool shallow = true,
    GbProgressCallback? onProgress,
  }) => _runWithProgress(onProgress, (callbackPtr) {
    return Isolate.run(() {
      final bindings = loadGit2Bridge();
      final urlPtr = url.toNativeUtf8(allocator: calloc);
      final pathPtr = path.toNativeUtf8(allocator: calloc);
      final tokenPtr = _optionalUtf8(token);
      try {
        return bindings.gb_clone(
          urlPtr.cast(),
          pathPtr.cast(),
          tokenPtr?.cast() ?? nullptr,
          shallow ? 1 : 0,
          callbackPtr,
          nullptr,
        );
      } finally {
        calloc.free(urlPtr);
        calloc.free(pathPtr);
        if (tokenPtr != null) calloc.free(tokenPtr);
      }
    });
  });

  /// Fetches `origin` and fast-forwards the current branch
  /// (`gb_pull`). Throws [GitBridgeException] with
  /// [GbErrorCode.nonFastForward] if the branches have diverged, or
  /// [GbErrorCode.uncommittedChanges] if the working tree is dirty
  /// (plan §5.4: fast-forward only).
  static Future<void> pull({
    required String path,
    String? token,
    GbProgressCallback? onProgress,
  }) => _runWithProgress(onProgress, (callbackPtr) {
    return Isolate.run(() {
      final bindings = loadGit2Bridge();
      final pathPtr = path.toNativeUtf8(allocator: calloc);
      final tokenPtr = _optionalUtf8(token);
      try {
        return bindings.gb_pull(
          pathPtr.cast(),
          tokenPtr?.cast() ?? nullptr,
          callbackPtr,
          nullptr,
        );
      } finally {
        calloc.free(pathPtr);
        if (tokenPtr != null) calloc.free(tokenPtr);
      }
    });
  });

  /// Pushes the current branch to its configured upstream
  /// (`gb_push`). Throws [GitBridgeException] with
  /// [GbErrorCode.noUpstream] if the branch has no upstream set.
  static Future<void> push({
    required String path,
    String? token,
    GbProgressCallback? onProgress,
  }) => _runWithProgress(onProgress, (callbackPtr) {
    return Isolate.run(() {
      final bindings = loadGit2Bridge();
      final pathPtr = path.toNativeUtf8(allocator: calloc);
      final tokenPtr = _optionalUtf8(token);
      try {
        return bindings.gb_push(
          pathPtr.cast(),
          tokenPtr?.cast() ?? nullptr,
          callbackPtr,
          nullptr,
        );
      } finally {
        calloc.free(pathPtr);
        if (tokenPtr != null) calloc.free(tokenPtr);
      }
    });
  });

  /// Initializes a new, non-bare repository at [path] (which must
  /// already exist, and may already contain files — e.g. content just
  /// extracted from a zip) with an initial branch named `main` and no
  /// commits (`gb_init`). Throws [GitBridgeException] with
  /// [GbErrorCode.exists] if [path] is already a git repository.
  static Future<void> init(String path) => Isolate.run(() {
    final bindings = loadGit2Bridge();
    final pathPtr = path.toNativeUtf8(allocator: calloc);
    try {
      final rc = bindings.gb_init(pathPtr.cast());
      throwIfError(rc, _lastErrorMessage(bindings));
    } finally {
      calloc.free(pathPtr);
    }
  });

  /// Adds [filePath] (relative to the repo root) to the index
  /// (`gb_stage`).
  static Future<void> stage({
    required String repoPath,
    required String filePath,
  }) => Isolate.run(() {
    final bindings = loadGit2Bridge();
    final repoPtr = repoPath.toNativeUtf8(allocator: calloc);
    final filePtr = filePath.toNativeUtf8(allocator: calloc);
    try {
      final rc = bindings.gb_stage(repoPtr.cast(), filePtr.cast());
      throwIfError(rc, _lastErrorMessage(bindings));
    } finally {
      calloc.free(repoPtr);
      calloc.free(filePtr);
    }
  });

  /// Removes [filePath] from the index, restoring the HEAD version of
  /// the entry without touching the working tree (`gb_unstage`).
  static Future<void> unstage({
    required String repoPath,
    required String filePath,
  }) => Isolate.run(() {
    final bindings = loadGit2Bridge();
    final repoPtr = repoPath.toNativeUtf8(allocator: calloc);
    final filePtr = filePath.toNativeUtf8(allocator: calloc);
    try {
      final rc = bindings.gb_unstage(repoPtr.cast(), filePtr.cast());
      throwIfError(rc, _lastErrorMessage(bindings));
    } finally {
      calloc.free(repoPtr);
      calloc.free(filePtr);
    }
  });

  /// Creates a commit from the current index on top of HEAD (or as
  /// the first commit if the repo is empty) (`gb_commit`).
  static Future<void> commit({
    required String repoPath,
    required String message,
    required String authorName,
    required String authorEmail,
  }) => Isolate.run(() {
    final bindings = loadGit2Bridge();
    final repoPtr = repoPath.toNativeUtf8(allocator: calloc);
    final msgPtr = message.toNativeUtf8(allocator: calloc);
    final namePtr = authorName.toNativeUtf8(allocator: calloc);
    final emailPtr = authorEmail.toNativeUtf8(allocator: calloc);
    try {
      final rc = bindings.gb_commit(
        repoPtr.cast(),
        msgPtr.cast(),
        namePtr.cast(),
        emailPtr.cast(),
      );
      throwIfError(rc, _lastErrorMessage(bindings));
    } finally {
      calloc.free(repoPtr);
      calloc.free(msgPtr);
      calloc.free(namePtr);
      calloc.free(emailPtr);
    }
  });

  /// Returns the working tree / index status of the repo at
  /// [repoPath] (`gb_get_status`).
  static Future<List<GbStatusEntry>> getStatus(String repoPath) =>
      Isolate.run(() {
        final bindings = loadGit2Bridge();
        final repoPtr = repoPath.toNativeUtf8(allocator: calloc);
        final outPtr = calloc<Pointer<Char>>();
        try {
          final rc = bindings.gb_get_status(repoPtr.cast(), outPtr);
          throwIfError(rc, _lastErrorMessage(bindings));
          final jsonStr = outPtr.value.cast<Utf8>().toDartString();
          bindings.gb_free_string(outPtr.value);
          final list = jsonDecode(jsonStr) as List<dynamic>;
          return list
              .map((e) => GbStatusEntry.fromJson(e as Map<String, dynamic>))
              .toList();
        } finally {
          calloc.free(repoPtr);
          calloc.free(outPtr);
        }
      });

  /// Lists the entries of [relPath] (relative to the repo root; `''`
  /// for the root) as tracked in HEAD's tree (`gb_get_file_tree`).
  static Future<List<GbTreeEntry>> getFileTree({
    required String repoPath,
    String relPath = '',
  }) => Isolate.run(() {
    final bindings = loadGit2Bridge();
    final repoPtr = repoPath.toNativeUtf8(allocator: calloc);
    final relPtr = relPath.toNativeUtf8(allocator: calloc);
    final outPtr = calloc<Pointer<Char>>();
    try {
      final rc = bindings.gb_get_file_tree(
        repoPtr.cast(),
        relPtr.cast(),
        outPtr,
      );
      throwIfError(rc, _lastErrorMessage(bindings));
      final jsonStr = outPtr.value.cast<Utf8>().toDartString();
      bindings.gb_free_string(outPtr.value);
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => GbTreeEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } finally {
      calloc.free(repoPtr);
      calloc.free(relPtr);
      calloc.free(outPtr);
    }
  });

  /// Returns whether [path] is a git repository (`gb_is_repository`).
  static Future<bool> isRepository(String path) => Isolate.run(() {
    final bindings = loadGit2Bridge();
    final pathPtr = path.toNativeUtf8(allocator: calloc);
    try {
      return bindings.gb_is_repository(pathPtr.cast()) == 1;
    } finally {
      calloc.free(pathPtr);
    }
  });

  /// Returns `null` if the repository has no commits yet (unborn HEAD).
  static Future<GbHeadInfo?> getHeadInfo(String repoPath) => Isolate.run(() {
    final bindings = loadGit2Bridge();
    final repoPtr = repoPath.toNativeUtf8(allocator: calloc);
    final outPtr = calloc<Pointer<Char>>();
    try {
      final rc = bindings.gb_get_head_info(repoPtr.cast(), outPtr);
      if (rc == GbErrorCode.unbornHead.code) return null;
      throwIfError(rc, _lastErrorMessage(bindings));
      final jsonStr = outPtr.value.cast<Utf8>().toDartString();
      bindings.gb_free_string(outPtr.value);
      return GbHeadInfo.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } finally {
      calloc.free(repoPtr);
      calloc.free(outPtr);
    }
  });

  /// Returns the number of commits on the current branch not yet
  /// present on its upstream; `0` if there is no upstream, or the
  /// repo is up to date (`gb_get_unpushed_count`).
  static Future<int> getUnpushedCount(String repoPath) => Isolate.run(() {
    final bindings = loadGit2Bridge();
    final repoPtr = repoPath.toNativeUtf8(allocator: calloc);
    final outCount = calloc<Int>();
    try {
      final rc = bindings.gb_get_unpushed_count(repoPtr.cast(), outCount);
      throwIfError(rc, _lastErrorMessage(bindings));
      return outCount.value;
    } finally {
      calloc.free(repoPtr);
      calloc.free(outCount);
    }
  });
}

Pointer<Utf8>? _optionalUtf8(String? value) {
  if (value == null || value.isEmpty) return null;
  return value.toNativeUtf8(allocator: calloc);
}

String _lastErrorMessage(Git2BridgeBindings bindings) {
  return bindings.gb_last_error_message().cast<Utf8>().toDartString();
}

/// `gb_progress.message` is a fixed `char[256]` embedded in the
/// struct (not a pointer), so it can't go through `Utf8.toDartString`
/// — read code units up to the first NUL instead.
String _fixedArrayToString(Array<Char> arr) {
  // Matches `char message[256]` in git_bridge.h's gb_progress struct.
  const messageCapacity = 256;
  final codes = <int>[];
  for (var i = 0; i < messageCapacity; i++) {
    final c = arr[i] & 0xFF;
    if (c == 0) break;
    codes.add(c);
  }
  return utf8.decode(codes, allowMalformed: true);
}

/// Wires a [NativeCallable.listener] on the *calling* isolate, hands
/// its native function pointer to [body] (which spawns the worker
/// isolate that performs the actual blocking FFI call), decodes each
/// `gb_progress` the native side reports and forwards it to
/// [onProgress], then tears the callable down once [body] completes.
///
/// Throws [GitBridgeException] if the worker isolate's result code is
/// non-zero.
Future<void> _runWithProgress(
  GbProgressCallback? onProgress,
  Future<int> Function(gb_progress_cb callbackPtr) body,
) async {
  NativeCallable<gb_progress_cbFunction>? callable;
  gb_progress_cb callbackPtr = nullptr;

  if (onProgress != null) {
    // Loaded on *this* isolate (the one that owns the listener, and
    // whose event loop stays free while the worker isolate blocks
    // inside the native call) purely to free each progress struct
    // after reading it — see the ownership note on gb_progress in
    // git_bridge.h.
    final localBindings = loadGit2Bridge();
    callable = NativeCallable<gb_progress_cbFunction>.listener((
      Pointer<gb_progress> progress,
      Pointer<Void> userData,
    ) {
      final p = progress.ref;
      onProgress(
        GbProgress(
          percent: p.percent,
          message: _fixedArrayToString(p.message),
          bytesReceived: p.bytes_received,
          totalObjects: p.total_objects,
          receivedObjects: p.received_objects,
        ),
      );
      localBindings.gb_free_progress(progress);
    });
    callbackPtr = callable.nativeFunction;
  }

  try {
    final rc = await body(callbackPtr);
    if (rc != 0) {
      // The worker isolate already ran gb_last_error_message() in its
      // own process image; libgit2's thread-local error state doesn't
      // cross the isolate boundary, so we surface the code only. See
      // Git2Bridge.{clone,pull,push} which forward the code as `rc`.
      throwIfError(rc, 'See error code for details.');
    }
  } finally {
    callable?.close();
  }
}
