// git_bridge.c
//
// Implementation of the flat C bridge declared in git_bridge.h. Thin
// wrapper around libgit2 — all it does is translate libgit2's
// object-oriented C API into a handful of flat, easily-FFI-bindable
// functions, own the memory it hands back across the FFI boundary,
// and build small JSON payloads by hand (no JSON library dependency
// on either side of the bridge).
#include "git_bridge.h"

#include <git2.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ---------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------

// Growable string buffer used to build JSON responses without pulling
// in a JSON library. Not thread-safe (each call gets its own buffer).
typedef struct {
  char* data;
  size_t len;
  size_t cap;
} gb_buf;

static void buf_init(gb_buf* b) {
  b->cap = 256;
  b->len = 0;
  b->data = (char*)malloc(b->cap);
  b->data[0] = '\0';
}

static void buf_ensure(gb_buf* b, size_t extra) {
  if (b->len + extra + 1 <= b->cap) return;
  while (b->len + extra + 1 > b->cap) b->cap *= 2;
  b->data = (char*)realloc(b->data, b->cap);
}

static void buf_append(gb_buf* b, const char* s) {
  size_t n = strlen(s);
  buf_ensure(b, n);
  memcpy(b->data + b->len, s, n);
  b->len += n;
  b->data[b->len] = '\0';
}

// Appends `s` as a JSON string literal, escaping quotes/backslashes/
// control characters.
static void buf_append_json_string(gb_buf* b, const char* s) {
  buf_append(b, "\"");
  for (const unsigned char* p = (const unsigned char*)s; *p; p++) {
    switch (*p) {
      case '"': buf_append(b, "\\\""); break;
      case '\\': buf_append(b, "\\\\"); break;
      case '\n': buf_append(b, "\\n"); break;
      case '\r': buf_append(b, "\\r"); break;
      case '\t': buf_append(b, "\\t"); break;
      default:
        if (*p < 0x20) {
          char esc[8];
          snprintf(esc, sizeof(esc), "\\u%04x", *p);
          buf_append(b, esc);
        } else {
          char c[2] = {(char)*p, '\0'};
          buf_append(b, c);
        }
    }
  }
  buf_append(b, "\"");
}

static char* gb_strdup_out(const char* s) {
  size_t n = strlen(s) + 1;
  char* out = (char*)malloc(n);
  memcpy(out, s, n);
  return out;
}

// Maps a libgit2 error code (and, for a couple of special cases, the
// error class) onto the smaller gb_error_code surface documented in
// git_bridge.h.
static int gb_map_git_error(int git_err) {
  const git_error* e = git_error_last();
  if (git_err == GIT_EAUTH || git_err == GIT_EUSER) {
    if (e && e->klass == GIT_ERROR_HTTP) return GB_ERROR_AUTH;
  }
  switch (git_err) {
    case 0: return GB_OK;
    case GIT_ENOTFOUND: return GB_ERROR_NOTFOUND;
    case GIT_EEXISTS: return GB_ERROR_EXISTS;
    case GIT_EAUTH: return GB_ERROR_AUTH;
    case GIT_ECERTIFICATE: return GB_ERROR_CERTIFICATE;
    case GIT_EUNCOMMITTED: return GB_ERROR_UNCOMMITTED;
    case GIT_ECONFLICT: return GB_ERROR_CONFLICT;
    case GIT_EINVALIDSPEC: return GB_ERROR_INVALIDSPEC;
    case GIT_EUSER: return GB_ERROR_CANCELLED;
    default:
      if (e && (e->klass == GIT_ERROR_NET || e->klass == GIT_ERROR_SSH)) {
        return GB_ERROR_NETWORK;
      }
      return GB_ERROR_GENERIC;
  }
}

const char* gb_last_error_message(void) {
  const git_error* e = git_error_last();
  return (e && e->message) ? e->message : "Unknown error";
}

int gb_global_init(void) { return git_libgit2_init() >= 0 ? GB_OK : GB_ERROR_GENERIC; }

int gb_global_shutdown(void) { return git_libgit2_shutdown() >= 0 ? GB_OK : GB_ERROR_GENERIC; }

void gb_free_string(char* str) { free(str); }

void gb_free_progress(gb_progress* progress) { free(progress); }

// ---------------------------------------------------------------------
// Auth / progress callbacks shared by clone, fetch (pull) and push
// ---------------------------------------------------------------------

typedef struct {
  const char* token;
  gb_progress_cb on_progress;
  void* user_data;
} gb_callback_ctx;

static int credentials_cb(git_credential** out, const char* url,
                           const char* username_from_url,
                           unsigned int allowed_types, void* payload) {
  (void)url;
  (void)username_from_url;
  gb_callback_ctx* ctx = (gb_callback_ctx*)payload;
  if (!ctx || !ctx->token || ctx->token[0] == '\0') {
    return GIT_EAUTH;
  }
  if (allowed_types & GIT_CREDENTIAL_USERPASS_PLAINTEXT) {
    // GitHub's HTTPS Basic auth for OAuth apps / PATs: any non-empty
    // username, token as the password. "oauth2" mirrors GitHub's own
    // documented convention for OAuth app tokens.
    return git_credential_userpass_plaintext_new(out, "oauth2", ctx->token);
  }
  return GIT_EAUTH;
}

static void emit_progress(gb_callback_ctx* ctx, int percent, const char* message,
                           uint64_t received, uint64_t total, uint64_t bytes) {
  if (!ctx || !ctx->on_progress) return;
  // Heap-allocated and owned by the callback (freed via
  // gb_free_progress) rather than stack-local: delivery through
  // NativeCallable.listener on the Dart side is asynchronous, so a
  // stack frame here could be reused before Dart reads it.
  gb_progress* p = (gb_progress*)calloc(1, sizeof(gb_progress));
  if (!p) return;
  p->percent = percent;
  p->received_objects = received;
  p->total_objects = total;
  p->bytes_received = bytes;
  snprintf(p->message, sizeof(p->message), "%s", message ? message : "");
  ctx->on_progress(p, ctx->user_data);
}

static int transfer_progress_cb(const git_indexer_progress* stats, void* payload) {
  gb_callback_ctx* ctx = (gb_callback_ctx*)payload;
  int percent = 0;
  if (stats->total_objects > 0) {
    percent = (int)(((uint64_t)(stats->indexed_objects) * 100) / stats->total_objects);
  }
  char msg[128];
  snprintf(msg, sizeof(msg), "Receiving objects: %u/%u", stats->indexed_objects,
           stats->total_objects);
  emit_progress(ctx, percent, msg, stats->received_objects, stats->total_objects,
                stats->received_bytes);
  return 0;
}

static int push_transfer_progress_cb(unsigned int current, unsigned int total,
                                      size_t bytes, void* payload) {
  gb_callback_ctx* ctx = (gb_callback_ctx*)payload;
  int percent = total > 0 ? (int)(((uint64_t)current * 100) / total) : 0;
  char msg[128];
  snprintf(msg, sizeof(msg), "Writing objects: %u/%u", current, total);
  emit_progress(ctx, percent, msg, current, total, (uint64_t)bytes);
  return 0;
}

static void checkout_progress_cb(const char* path, size_t completed_steps,
                                  size_t total_steps, void* payload) {
  gb_callback_ctx* ctx = (gb_callback_ctx*)payload;
  int percent = total_steps > 0 ? (int)(((uint64_t)completed_steps * 100) / total_steps) : 0;
  char msg[192];
  snprintf(msg, sizeof(msg), "Checking out: %s", path ? path : "");
  emit_progress(ctx, percent, msg, completed_steps, total_steps, 0);
}

// ---------------------------------------------------------------------
// gb_clone
// ---------------------------------------------------------------------

int gb_clone(const char* url, const char* path, const char* token, int shallow,
             gb_progress_cb on_progress, void* user_data) {
  gb_callback_ctx ctx = {token, on_progress, user_data};

  git_clone_options opts;
  // The static GIT_CLONE_OPTIONS_INIT macro has, in practice, failed
  // to cascade-initialize the .version field of newly-added nested
  // structs (e.g. git_proxy_options inside fetch_opts) across libgit2
  // releases — git_clone_options_init() is the version-safe function
  // form libgit2 itself recommends, and cascades correctly.
  git_clone_options_init(&opts, GIT_CLONE_OPTIONS_VERSION);
  opts.fetch_opts.callbacks.credentials = credentials_cb;
  opts.fetch_opts.callbacks.transfer_progress = transfer_progress_cb;
  opts.fetch_opts.callbacks.payload = &ctx;
  opts.checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE;
  opts.checkout_opts.progress_cb = checkout_progress_cb;
  opts.checkout_opts.progress_payload = &ctx;
  if (shallow) {
    opts.fetch_opts.depth = 1;
  }

  git_repository* repo = NULL;
  int rc = git_clone(&repo, url, path, &opts);
  if (repo) git_repository_free(repo);
  if (rc != 0) return gb_map_git_error(rc);
  emit_progress(&ctx, 100, "Clone complete", 0, 0, 0);
  return GB_OK;
}

// ---------------------------------------------------------------------
// gb_pull  (fetch origin, then fast-forward only)
// ---------------------------------------------------------------------

int gb_pull(const char* path, const char* token, gb_progress_cb on_progress,
            void* user_data) {
  gb_callback_ctx ctx = {token, on_progress, user_data};
  git_repository* repo = NULL;
  git_remote* remote = NULL;
  git_reference* head_ref = NULL;
  git_reference* upstream_ref = NULL;
  git_annotated_commit* their_head = NULL;
  int rc;
  int result = GB_OK;

  rc = git_repository_open(&repo, path);
  if (rc != 0) return gb_map_git_error(rc);

  // Refuse to pull over a dirty working tree — MVP has no merge UX to
  // reconcile local edits with incoming changes.
  git_status_list* dirty_check = NULL;
  git_status_options status_opts;
  git_status_options_init(&status_opts, GIT_STATUS_OPTIONS_VERSION);
  status_opts.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR;
  if (git_status_list_new(&dirty_check, repo, &status_opts) == 0) {
    size_t dirty_count = git_status_list_entrycount(dirty_check);
    git_status_list_free(dirty_check);
    if (dirty_count > 0) {
      git_repository_free(repo);
      return GB_ERROR_UNCOMMITTED;
    }
  }

  rc = git_remote_lookup(&remote, repo, "origin");
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  git_fetch_options fetch_opts;
  git_fetch_options_init(&fetch_opts, GIT_FETCH_OPTIONS_VERSION);
  fetch_opts.callbacks.credentials = credentials_cb;
  fetch_opts.callbacks.transfer_progress = transfer_progress_cb;
  fetch_opts.callbacks.payload = &ctx;

  rc = git_remote_fetch(remote, NULL, &fetch_opts, "pull");
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  rc = git_repository_head(&head_ref, repo);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  rc = git_branch_upstream(&upstream_ref, head_ref);
  if (rc != 0) { result = GB_ERROR_NO_UPSTREAM; goto cleanup; }

  rc = git_annotated_commit_from_ref(&their_head, repo, upstream_ref);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  git_merge_analysis_t analysis;
  git_merge_preference_t preference;
  const git_annotated_commit* their_heads[1] = {their_head};
  rc = git_merge_analysis(&analysis, &preference, repo, their_heads, 1);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  if (analysis & GIT_MERGE_ANALYSIS_UP_TO_DATE) {
    result = GB_OK;
    goto cleanup;
  }
  if (!(analysis & GIT_MERGE_ANALYSIS_FASTFORWARD)) {
    // Diverged history or unborn branch that isn't a trivial fast
    // forward: out of scope for MVP (see plan §5.4).
    result = GB_ERROR_NONFASTFORWARD;
    goto cleanup;
  }

  const git_oid* target_oid = git_annotated_commit_id(their_head);
  git_object* target_obj = NULL;
  rc = git_object_lookup(&target_obj, repo, target_oid, GIT_OBJECT_COMMIT);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  git_checkout_options checkout_opts;
  git_checkout_options_init(&checkout_opts, GIT_CHECKOUT_OPTIONS_VERSION);
  checkout_opts.checkout_strategy = GIT_CHECKOUT_SAFE;
  checkout_opts.progress_cb = checkout_progress_cb;
  checkout_opts.progress_payload = &ctx;
  rc = git_checkout_tree(repo, target_obj, &checkout_opts);
  git_object_free(target_obj);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  git_reference* new_head_ref = NULL;
  rc = git_reference_set_target(&new_head_ref, head_ref, target_oid,
                                 "pull: fast-forward");
  if (new_head_ref) git_reference_free(new_head_ref);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  emit_progress(&ctx, 100, "Fast-forwarded", 0, 0, 0);

cleanup:
  if (their_head) git_annotated_commit_free(their_head);
  if (upstream_ref) git_reference_free(upstream_ref);
  if (head_ref) git_reference_free(head_ref);
  if (remote) git_remote_free(remote);
  if (repo) git_repository_free(repo);
  return result;
}

// ---------------------------------------------------------------------
// gb_push
// ---------------------------------------------------------------------

int gb_push(const char* path, const char* token, gb_progress_cb on_progress,
            void* user_data) {
  gb_callback_ctx ctx = {token, on_progress, user_data};
  git_repository* repo = NULL;
  git_reference* head_ref = NULL;
  git_remote* remote = NULL;
  int rc;
  int result = GB_OK;

  rc = git_repository_open(&repo, path);
  if (rc != 0) return gb_map_git_error(rc);

  rc = git_repository_head(&head_ref, repo);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  if (!git_reference_is_branch(head_ref)) {
    result = GB_ERROR_INVALIDSPEC;
    goto cleanup;
  }

  // Validate an upstream is configured before attempting to push, so
  // we can return the more specific GB_ERROR_NO_UPSTREAM.
  git_buf remote_name = {0};
  rc = git_branch_upstream_remote(&remote_name, repo, git_reference_name(head_ref));
  if (rc != 0) {
    result = GB_ERROR_NO_UPSTREAM;
    goto cleanup;
  }

  rc = git_remote_lookup(&remote, repo, remote_name.ptr);
  git_buf_dispose(&remote_name);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  const char* branch_ref_name = git_reference_name(head_ref);
  char refspec[512];
  snprintf(refspec, sizeof(refspec), "%s:%s", branch_ref_name, branch_ref_name);
  char* refspecs_arr[1] = {refspec};
  git_strarray refspecs = {refspecs_arr, 1};

  git_push_options push_opts;
  git_push_options_init(&push_opts, GIT_PUSH_OPTIONS_VERSION);
  push_opts.callbacks.credentials = credentials_cb;
  push_opts.callbacks.push_transfer_progress = push_transfer_progress_cb;
  push_opts.callbacks.payload = &ctx;

  rc = git_remote_push(remote, &refspecs, &push_opts);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  emit_progress(&ctx, 100, "Push complete", 0, 0, 0);

cleanup:
  if (remote) git_remote_free(remote);
  if (head_ref) git_reference_free(head_ref);
  if (repo) git_repository_free(repo);
  return result;
}

// ---------------------------------------------------------------------
// gb_init
// ---------------------------------------------------------------------

int gb_init(const char* path) {
  if (gb_is_repository(path)) return GB_ERROR_EXISTS;

  git_repository_init_options opts;
  git_repository_init_options_init(&opts, GIT_REPOSITORY_INIT_OPTIONS_VERSION);
  opts.initial_head = "main";

  git_repository* repo = NULL;
  int rc = git_repository_init_ext(&repo, path, &opts);
  if (repo) git_repository_free(repo);
  return gb_map_git_error(rc);
}

// ---------------------------------------------------------------------
// gb_stage / gb_unstage
// ---------------------------------------------------------------------

int gb_stage(const char* repo_path, const char* file_path) {
  git_repository* repo = NULL;
  git_index* index = NULL;
  int rc = git_repository_open(&repo, repo_path);
  if (rc != 0) return gb_map_git_error(rc);

  rc = git_repository_index(&index, repo);
  if (rc != 0) { git_repository_free(repo); return gb_map_git_error(rc); }

  rc = git_index_add_bypath(index, file_path);
  if (rc == 0) rc = git_index_write(index);

  git_index_free(index);
  git_repository_free(repo);
  return gb_map_git_error(rc);
}

int gb_unstage(const char* repo_path, const char* file_path) {
  git_repository* repo = NULL;
  int rc = git_repository_open(&repo, repo_path);
  if (rc != 0) return gb_map_git_error(rc);

  git_object* head_commit = NULL;
  // Resolve HEAD^{commit}; tolerate an unborn HEAD (empty repo) by
  // resetting against NULL, which git_reset_default handles as
  // "remove from index".
  int head_rc = git_revparse_single(&head_commit, repo, "HEAD^{commit}");

  char* paths_arr[1] = {(char*)file_path};
  git_strarray paths = {paths_arr, 1};
  int rc2 = git_reset_default(repo, head_rc == 0 ? head_commit : NULL, &paths);

  if (head_commit) git_object_free(head_commit);
  git_repository_free(repo);
  return gb_map_git_error(rc2);
}

// ---------------------------------------------------------------------
// gb_commit
// ---------------------------------------------------------------------

int gb_commit(const char* repo_path, const char* message, const char* author_name,
              const char* author_email) {
  git_repository* repo = NULL;
  git_index* index = NULL;
  git_signature* sig = NULL;
  git_tree* tree = NULL;
  git_oid tree_oid, commit_oid;
  git_object* parent_obj = NULL;
  git_reference* head_ref = NULL;
  int result = GB_OK;
  int rc;

  rc = git_repository_open(&repo, repo_path);
  if (rc != 0) return gb_map_git_error(rc);

  rc = git_signature_now(&sig, author_name, author_email);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  rc = git_repository_index(&index, repo);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  rc = git_index_write_tree(&tree_oid, index);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  rc = git_tree_lookup(&tree, repo, &tree_oid);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  // First commit in a fresh repo has no parent (unborn HEAD).
  int head_unborn = git_repository_head_unborn(repo);
  const git_commit* parents[1];
  size_t parent_count = 0;
  if (head_unborn == 0) {
    rc = git_revparse_single(&parent_obj, repo, "HEAD^{commit}");
    if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }
    parents[0] = (const git_commit*)parent_obj;
    parent_count = 1;
  }

  rc = git_commit_create(&commit_oid, repo, "HEAD", sig, sig, "UTF-8", message,
                          tree, parent_count, parents);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

  rc = git_index_write(index);
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }

cleanup:
  if (parent_obj) git_object_free(parent_obj);
  if (tree) git_tree_free(tree);
  if (index) git_index_free(index);
  if (sig) git_signature_free(sig);
  if (head_ref) git_reference_free(head_ref);
  if (repo) git_repository_free(repo);
  return result;
}

// ---------------------------------------------------------------------
// gb_get_status
// ---------------------------------------------------------------------

static const char* status_label(git_status_t s, int* out_staged) {
  *out_staged = (s & (GIT_STATUS_INDEX_NEW | GIT_STATUS_INDEX_MODIFIED |
                       GIT_STATUS_INDEX_DELETED | GIT_STATUS_INDEX_RENAMED |
                       GIT_STATUS_INDEX_TYPECHANGE)) != 0;
  if (s & (GIT_STATUS_INDEX_NEW | GIT_STATUS_WT_NEW)) return "added";
  if (s & (GIT_STATUS_INDEX_DELETED | GIT_STATUS_WT_DELETED)) return "deleted";
  if (s & (GIT_STATUS_INDEX_RENAMED | GIT_STATUS_WT_RENAMED)) return "renamed";
  if (s & (GIT_STATUS_INDEX_TYPECHANGE | GIT_STATUS_WT_TYPECHANGE)) return "typechange";
  if (s & GIT_STATUS_CONFLICTED) return "conflicted";
  return "modified";
}

int gb_get_status(const char* repo_path, char** json_output) {
  git_repository* repo = NULL;
  git_status_list* list = NULL;
  int rc = git_repository_open(&repo, repo_path);
  if (rc != 0) return gb_map_git_error(rc);

  git_status_options opts;
  git_status_options_init(&opts, GIT_STATUS_OPTIONS_VERSION);
  opts.show = GIT_STATUS_SHOW_INDEX_AND_WORKDIR;
  opts.flags = GIT_STATUS_OPT_INCLUDE_UNTRACKED |
               GIT_STATUS_OPT_RECURSE_UNTRACKED_DIRS;

  rc = git_status_list_new(&list, repo, &opts);
  if (rc != 0) { git_repository_free(repo); return gb_map_git_error(rc); }

  gb_buf buf;
  buf_init(&buf);
  buf_append(&buf, "[");
  size_t count = git_status_list_entrycount(list);
  for (size_t i = 0; i < count; i++) {
    const git_status_entry* entry = git_status_byindex(list, i);
    const char* path = entry->index_to_workdir
                            ? entry->index_to_workdir->new_file.path
                            : (entry->head_to_index ? entry->head_to_index->new_file.path
                                                     : NULL);
    if (!path) continue;
    int staged = 0;
    const char* label = status_label(entry->status, &staged);
    if (i > 0) buf_append(&buf, ",");
    buf_append(&buf, "{\"path\":");
    buf_append_json_string(&buf, path);
    buf_append(&buf, ",\"status\":\"");
    buf_append(&buf, label);
    buf_append(&buf, "\",\"staged\":");
    buf_append(&buf, staged ? "true" : "false");
    buf_append(&buf, "}");
  }
  buf_append(&buf, "]");

  git_status_list_free(list);
  git_repository_free(repo);
  *json_output = buf.data;
  return GB_OK;
}

// ---------------------------------------------------------------------
// gb_get_file_tree
// ---------------------------------------------------------------------

int gb_get_file_tree(const char* repo_path, const char* rel_path, char** json_output) {
  git_repository* repo = NULL;
  git_tree* root_tree = NULL;
  git_tree* target_tree = NULL;
  git_object* head_commit = NULL;
  int result = GB_OK;

  int rc = git_repository_open(&repo, repo_path);
  if (rc != 0) return gb_map_git_error(rc);

  if (git_repository_head_unborn(repo)) {
    // No commits yet: report an empty tree rather than erroring, so
    // the UI can render "this repo has no commits yet".
    git_repository_free(repo);
    *json_output = gb_strdup_out("[]");
    return GB_OK;
  }

  rc = git_revparse_single(&head_commit, repo, "HEAD^{tree}");
  if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }
  root_tree = (git_tree*)head_commit;
  head_commit = NULL;

  if (rel_path && rel_path[0] != '\0') {
    git_tree_entry* entry = NULL;
    rc = git_tree_entry_bypath(&entry, root_tree, rel_path);
    if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }
    if (git_tree_entry_type(entry) != GIT_OBJECT_TREE) {
      git_tree_entry_free(entry);
      result = GB_ERROR_INVALIDSPEC;
      goto cleanup;
    }
    rc = git_tree_lookup(&target_tree, repo, git_tree_entry_id(entry));
    git_tree_entry_free(entry);
    if (rc != 0) { result = gb_map_git_error(rc); goto cleanup; }
  } else {
    target_tree = root_tree;
    root_tree = NULL;
  }

  gb_buf buf;
  buf_init(&buf);
  buf_append(&buf, "[");
  size_t count = git_tree_entrycount(target_tree);
  for (size_t i = 0; i < count; i++) {
    const git_tree_entry* entry = git_tree_entry_byindex(target_tree, i);
    const char* name = git_tree_entry_name(entry);
    git_object_t type = git_tree_entry_type(entry);
    if (i > 0) buf_append(&buf, ",");
    buf_append(&buf, "{\"name\":");
    buf_append_json_string(&buf, name);
    buf_append(&buf, ",\"path\":");
    if (rel_path && rel_path[0] != '\0') {
      char full[1024];
      snprintf(full, sizeof(full), "%s/%s", rel_path, name);
      buf_append_json_string(&buf, full);
    } else {
      buf_append_json_string(&buf, name);
    }
    buf_append(&buf, ",\"type\":\"");
    buf_append(&buf, type == GIT_OBJECT_TREE ? "tree" : "blob");
    buf_append(&buf, "\"");
    if (type == GIT_OBJECT_BLOB) {
      git_object* blob_obj = NULL;
      if (git_tree_entry_to_object(&blob_obj, repo, entry) == 0) {
        char size_str[32];
        snprintf(size_str, sizeof(size_str), "%lld",
                  (long long)git_blob_rawsize((const git_blob*)blob_obj));
        buf_append(&buf, ",\"size\":");
        buf_append(&buf, size_str);
        git_object_free(blob_obj);
      }
    }
    buf_append(&buf, "}");
  }
  buf_append(&buf, "]");
  *json_output = buf.data;

cleanup:
  if (head_commit) git_object_free(head_commit);
  if (target_tree) git_tree_free(target_tree);
  if (root_tree) git_tree_free(root_tree);
  if (repo) git_repository_free(repo);
  return result;
}

// ---------------------------------------------------------------------
// gb_is_repository
// ---------------------------------------------------------------------

int gb_is_repository(const char* path) {
  git_repository* repo = NULL;
  int rc = git_repository_open(&repo, path);
  if (repo) git_repository_free(repo);
  return rc == 0 ? 1 : 0;
}

// ---------------------------------------------------------------------
// gb_get_head_info
// ---------------------------------------------------------------------

int gb_get_head_info(const char* repo_path, char** json_output) {
  git_repository* repo = NULL;
  int rc = git_repository_open(&repo, repo_path);
  if (rc != 0) return gb_map_git_error(rc);

  if (git_repository_head_unborn(repo)) {
    git_repository_free(repo);
    return GB_ERROR_UNBORN_HEAD;
  }

  git_reference* head_ref = NULL;
  rc = git_repository_head(&head_ref, repo);
  if (rc != 0) { git_repository_free(repo); return gb_map_git_error(rc); }

  git_object* commit_obj = NULL;
  rc = git_reference_peel(&commit_obj, head_ref, GIT_OBJECT_COMMIT);
  if (rc != 0) {
    git_reference_free(head_ref);
    git_repository_free(repo);
    return gb_map_git_error(rc);
  }

  char sha[16];
  git_oid_tostr(sha, sizeof(sha), git_object_id(commit_obj));
  const char* summary = git_commit_summary((git_commit*)commit_obj);
  const char* branch = NULL;
  git_branch_name(&branch, head_ref);

  gb_buf buf;
  buf_init(&buf);
  buf_append(&buf, "{\"sha\":");
  buf_append_json_string(&buf, sha);
  buf_append(&buf, ",\"summary\":");
  buf_append_json_string(&buf, summary ? summary : "");
  buf_append(&buf, ",\"branch\":");
  buf_append_json_string(&buf, branch ? branch : "");
  buf_append(&buf, "}");
  *json_output = buf.data;

  git_object_free(commit_obj);
  git_reference_free(head_ref);
  git_repository_free(repo);
  return GB_OK;
}

// ---------------------------------------------------------------------
// gb_get_unpushed_count
// ---------------------------------------------------------------------

int gb_get_unpushed_count(const char* repo_path, int* out_count) {
  *out_count = 0;
  git_repository* repo = NULL;
  int rc = git_repository_open(&repo, repo_path);
  if (rc != 0) return gb_map_git_error(rc);

  if (git_repository_head_unborn(repo)) {
    git_repository_free(repo);
    return GB_OK;
  }

  git_reference* head_ref = NULL;
  rc = git_repository_head(&head_ref, repo);
  if (rc != 0) { git_repository_free(repo); return gb_map_git_error(rc); }

  git_reference* upstream_ref = NULL;
  rc = git_branch_upstream(&upstream_ref, head_ref);
  if (rc != 0) {
    // No upstream configured: nothing to compare against.
    git_reference_free(head_ref);
    git_repository_free(repo);
    return GB_OK;
  }

  const git_oid* local_oid = git_reference_target(head_ref);
  const git_oid* upstream_oid = git_reference_target(upstream_ref);
  size_t ahead = 0, behind = 0;
  int result = GB_OK;
  if (local_oid && upstream_oid) {
    rc = git_graph_ahead_behind(&ahead, &behind, repo, local_oid, upstream_oid);
    if (rc != 0) {
      result = gb_map_git_error(rc);
    } else {
      *out_count = (int)ahead;
    }
  }

  git_reference_free(upstream_ref);
  git_reference_free(head_ref);
  git_repository_free(repo);
  return result;
}
