// git_bridge.h
//
// Flat C ABI wrapper around libgit2, exposed to Dart via dart:ffi.
// Every call is synchronous and blocking — callers MUST invoke these
// functions from a background Isolate (see lib/core/isolate), never
// from the UI isolate.
//
// Memory ownership: any `char**`/`char*` output parameter documented as
// "caller must free" is allocated with malloc() on the native side and
// must be released with gb_free_string(). Callers must never call
// free() directly on a pointer returned across the FFI boundary.
#ifndef GIT_BRIDGE_H
#define GIT_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

// Error codes returned by gb_* functions. Values <= 0 mirror the
// subset of libgit2's git_error_code that the bridge surfaces
// directly; values > 0 are bridge-specific.
typedef enum {
  GB_OK = 0,
  GB_ERROR_GENERIC = -1,
  GB_ERROR_NOTFOUND = -3,
  GB_ERROR_EXISTS = -4,
  GB_ERROR_AUTH = -16,
  GB_ERROR_NONFASTFORWARD = -11,
  GB_ERROR_CERTIFICATE = -17,
  GB_ERROR_UNCOMMITTED = -20,
  GB_ERROR_CONFLICT = -21,
  GB_ERROR_INVALIDSPEC = -22,
  GB_ERROR_NETWORK = 100,
  GB_ERROR_CANCELLED = 101,
  GB_ERROR_NO_UPSTREAM = 102,
  GB_ERROR_UNBORN_HEAD = 103,
} gb_error_code;

// Progress callback payload. `percent` is 0-100 (best-effort; some
// libgit2 phases cannot report a precise percentage, in which case
// -1 is sent with a descriptive `message`).
//
// Ownership: each instance passed to a gb_progress_cb is individually
// heap-allocated by the bridge and OWNED BY THE CALLBACK — it must be
// released with gb_free_progress() once the callback is done reading
// it. This matters because callback delivery across the Dart FFI
// boundary (NativeCallable.listener) is asynchronous: the native
// thread does not block waiting for Dart to consume the struct, so it
// must not be stack-allocated or reused between calls.
typedef struct {
  int32_t percent;
  char message[256];
  uint64_t bytes_received;
  uint64_t total_objects;
  uint64_t received_objects;
} gb_progress;

// Optional push-style progress callback. `user_data` is passed through
// unchanged from the call site (e.g. a pointer to a Dart
// SendPort-backed NativeCallable on platforms that support it).
// The callback takes ownership of `progress` — see the ownership note
// on gb_progress above — and must release it via gb_free_progress().
typedef void (*gb_progress_cb)(gb_progress* progress, void* user_data);

// ---------------------------------------------------------------------
// Repository lifecycle
// ---------------------------------------------------------------------

// Clones `url` into `path`. `token` is a GitHub OAuth access token used
// as the HTTPS password (username is fixed to "oauth2"); pass NULL for
// unauthenticated clones of public repos. `shallow` performs a
// depth=1 clone when non-zero.
int gb_clone(const char* url, const char* path, const char* token,
             int shallow, gb_progress_cb on_progress, void* user_data);

// Fetches `origin` and fast-forwards the current branch. Fails with
// GB_ERROR_NONFASTFORWARD if the branches have diverged (MVP does not
// support merge/rebase) and GB_ERROR_UNCOMMITTED if the working tree
// has local changes that would be overwritten.
int gb_pull(const char* path, const char* token, gb_progress_cb on_progress,
            void* user_data);

// Pushes the current branch to its configured upstream. Fails with
// GB_ERROR_NO_UPSTREAM if the branch has no upstream configured.
int gb_push(const char* path, const char* token, gb_progress_cb on_progress,
            void* user_data);

// ---------------------------------------------------------------------
// Local operations
// ---------------------------------------------------------------------

// Adds `file_path` (relative to repo root) to the index.
int gb_stage(const char* repo_path, const char* file_path);

// Removes `file_path` from the index, restoring the HEAD version of
// the entry (does not touch the working tree).
int gb_unstage(const char* repo_path, const char* file_path);

// Creates a commit from the current index on top of HEAD (or as the
// first commit if the repo is empty).
int gb_commit(const char* repo_path, const char* message,
              const char* author_name, const char* author_email);

// ---------------------------------------------------------------------
// Status & queries
// ---------------------------------------------------------------------

// Writes a JSON array describing the working tree / index status to
// *json_output, e.g.:
//   [{"path":"src/main.dart","status":"modified","staged":false}, ...]
// Caller must free *json_output via gb_free_string.
int gb_get_status(const char* repo_path, char** json_output);

// Writes a JSON array describing the entries of `rel_path` (relative
// to repo root; "" for repo root) as tracked in HEAD's tree, e.g.:
//   [{"name":"lib","path":"lib","type":"tree"},
//    {"name":"pubspec.yaml","path":"pubspec.yaml","type":"blob","size":512}]
// Caller must free *json_output via gb_free_string.
int gb_get_file_tree(const char* repo_path, const char* rel_path,
                      char** json_output);

// Returns 1 if `path` is a git repository (has a .git directory), 0
// otherwise. Does not allocate.
int gb_is_repository(const char* path);

// Writes the short SHA + summary of HEAD to *json_output, e.g.:
//   {"sha":"a1b2c3d","summary":"Fix crash on empty repo","branch":"main"}
// Caller must free *json_output via gb_free_string. Returns
// GB_ERROR_UNBORN_HEAD if the repo exists but has no commits yet, and
// GB_ERROR_NOTFOUND if `repo_path` isn't a git repository at all.
int gb_get_head_info(const char* repo_path, char** json_output);

// Returns the number of commits on the current branch that are not
// yet present on its upstream (0 if there is no upstream, or the repo
// is up to date). Used to populate the "unpushed_commits" badge.
int gb_get_unpushed_count(const char* repo_path, int* out_count);

// ---------------------------------------------------------------------
// Diagnostics
// ---------------------------------------------------------------------

// Returns a static, human-readable string for the most recent libgit2
// error on this thread (mirrors git_error_last()). Never NULL. Do NOT
// free the returned pointer.
const char* gb_last_error_message(void);

// ---------------------------------------------------------------------
// Cleanup / lifecycle
// ---------------------------------------------------------------------

// One-time global libgit2 init. Safe to call multiple times (ref
// counted internally by libgit2). Call once per Isolate before any
// other gb_* function.
int gb_global_init(void);

// Mirrors git_libgit2_shutdown(). Call when an Isolate is done issuing
// git operations, if it will not issue any more.
int gb_global_shutdown(void);

// Frees a string previously returned by this API via an output
// parameter (gb_get_status, gb_get_file_tree, gb_get_head_info).
void gb_free_string(char* str);

// Frees a gb_progress instance delivered to a gb_progress_cb. See the
// ownership note on gb_progress above.
void gb_free_progress(gb_progress* progress);

#ifdef __cplusplus
}
#endif

#endif  // GIT_BRIDGE_H
