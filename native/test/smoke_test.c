// Standalone smoke test for git_bridge.c, compiled + run directly
// against the system libgit2 (Linux dev machine only). Not part of
// the Flutter build — see scripts/native_smoke_test.sh.
#include <stdio.h>
#include <string.h>
#include "git_bridge.h"

static int failures = 0;

#define CHECK(cond, msg)                                                     \
  do {                                                                       \
    if (!(cond)) {                                                           \
      printf("FAIL: %s (%s:%d) — %s\n", msg, __FILE__, __LINE__,             \
             gb_last_error_message());                                       \
      failures++;                                                            \
    } else {                                                                 \
      printf("OK:   %s\n", msg);                                             \
    }                                                                        \
  } while (0)

static void on_progress(const gb_progress* p, void* user_data) {
  (void)user_data;
  printf("  progress: %d%% %s\n", p->percent, p->message);
}

int main(void) {
  gb_global_init();

  const char* origin_path = "/tmp/gb_smoke_origin";
  const char* seed_path = "/tmp/gb_smoke_seed";
  const char* clone_path = "/tmp/gb_smoke_clone";
  char cmd[512];
  snprintf(cmd, sizeof(cmd), "rm -rf %s %s %s", origin_path, seed_path, clone_path);
  system(cmd);

  // Real git remotes (GitHub included) are always bare, and libgit2
  // refuses `push` into a non-bare repo's currently-checked-out
  // branch — so the fixture "remote" must be bare too, seeded via a
  // throwaway working checkout.
  snprintf(cmd, sizeof(cmd), "git init -q --bare -b main %s", origin_path);
  system(cmd);
  snprintf(cmd, sizeof(cmd),
           "git clone -q %s %s && cd %s && git config user.email a@b.com && "
           "git config user.name Test && echo hello > README.md && git add "
           "README.md && git commit -q -m 'initial commit' && git push -q origin main",
           origin_path, seed_path, seed_path);
  system(cmd);

  char origin_url[600];
  snprintf(origin_url, sizeof(origin_url), "file://%s", origin_path);

  int rc = gb_clone(origin_url, clone_path, NULL, /*shallow=*/0, on_progress, NULL);
  CHECK(rc == GB_OK, "gb_clone from file:// origin");

  CHECK(gb_is_repository(clone_path) == 1, "gb_is_repository true after clone");

  char* json = NULL;
  rc = gb_get_head_info(clone_path, &json);
  CHECK(rc == GB_OK && json != NULL, "gb_get_head_info after clone");
  if (json) {
    printf("  head info: %s\n", json);
    CHECK(strstr(json, "\"branch\":\"main\"") != NULL, "head info reports branch main");
    gb_free_string(json);
  }

  rc = gb_get_file_tree(clone_path, "", &json);
  CHECK(rc == GB_OK && json != NULL, "gb_get_file_tree root");
  if (json) {
    printf("  tree: %s\n", json);
    CHECK(strstr(json, "README.md") != NULL, "tree lists README.md");
    gb_free_string(json);
  }

  // Write a new file, stage it, commit it.
  char newfile[600];
  snprintf(newfile, sizeof(newfile), "%s/NOTES.md", clone_path);
  FILE* f = fopen(newfile, "w");
  CHECK(f != NULL, "create NOTES.md in working tree");
  if (f) {
    fprintf(f, "some notes\n");
    fclose(f);
  }

  rc = gb_get_status(clone_path, &json);
  CHECK(rc == GB_OK && json != NULL, "gb_get_status sees untracked file");
  if (json) {
    printf("  status: %s\n", json);
    CHECK(strstr(json, "NOTES.md") != NULL, "status lists NOTES.md");
    gb_free_string(json);
  }

  rc = gb_stage(clone_path, "NOTES.md");
  CHECK(rc == GB_OK, "gb_stage NOTES.md");

  rc = gb_get_status(clone_path, &json);
  if (json) {
    CHECK(strstr(json, "\"staged\":true") != NULL, "status shows staged:true after stage");
    gb_free_string(json);
  }

  rc = gb_commit(clone_path, "Add notes", "Test User", "test@example.com");
  CHECK(rc == GB_OK, "gb_commit staged NOTES.md");

  int unpushed = -1;
  rc = gb_get_unpushed_count(clone_path, &unpushed);
  CHECK(rc == GB_OK, "gb_get_unpushed_count after local commit");
  printf("  unpushed_count=%d\n", unpushed);
  CHECK(unpushed == 1, "one unpushed commit ahead of origin/main");

  rc = gb_push(clone_path, NULL, on_progress, NULL);
  CHECK(rc == GB_OK, "gb_push back to file:// origin");

  rc = gb_get_unpushed_count(clone_path, &unpushed);
  CHECK(rc == GB_OK && unpushed == 0, "zero unpushed commits after push");

  // Second clone to exercise pull fast-forward.
  const char* clone2_path = "/tmp/gb_smoke_clone2";
  snprintf(cmd, sizeof(cmd), "rm -rf %s", clone2_path);
  system(cmd);
  rc = gb_clone(origin_url, clone2_path, NULL, 0, on_progress, NULL);
  CHECK(rc == GB_OK, "second clone for pull test");

  rc = gb_pull(clone2_path, NULL, on_progress, NULL);
  CHECK(rc == GB_OK, "gb_pull picks up NOTES.md pushed from clone1");

  rc = gb_get_file_tree(clone2_path, "", &json);
  if (json) {
    CHECK(strstr(json, "NOTES.md") != NULL, "clone2 tree has NOTES.md after pull");
    gb_free_string(json);
  }

  // gb_init: importing a plain folder (e.g. extracted from a zip)
  // with no prior git history as a new local repository.
  const char* init_path = "/tmp/gb_smoke_init";
  snprintf(cmd, sizeof(cmd), "rm -rf %s && mkdir -p %s", init_path, init_path);
  system(cmd);
  snprintf(cmd, sizeof(cmd), "echo hello > %s/README.md", init_path);
  system(cmd);

  CHECK(gb_is_repository(init_path) == 0, "plain folder is not a repository before gb_init");
  rc = gb_init(init_path);
  CHECK(rc == GB_OK, "gb_init on a plain folder");
  CHECK(gb_is_repository(init_path) == 1, "gb_is_repository true after gb_init");
  CHECK(gb_init(init_path) == GB_ERROR_EXISTS, "gb_init on an already-initialized repo returns GB_ERROR_EXISTS");

  rc = gb_get_head_info(init_path, &json);
  CHECK(rc == GB_ERROR_UNBORN_HEAD, "gb_get_head_info on a fresh gb_init repo reports unborn HEAD");

  rc = gb_get_status(init_path, &json);
  CHECK(rc == GB_OK && json != NULL, "gb_get_status on freshly-init'd repo");
  if (json) {
    printf("  status: %s\n", json);
    CHECK(strstr(json, "README.md") != NULL, "status shows README.md as untracked");
    gb_free_string(json);
  }

  rc = gb_stage(init_path, "README.md");
  CHECK(rc == GB_OK, "gb_stage on freshly-init'd repo");
  rc = gb_commit(init_path, "Initial import", "Test User", "test@example.com");
  CHECK(rc == GB_OK, "gb_commit the first commit on a gb_init'd repo");

  rc = gb_get_head_info(init_path, &json);
  CHECK(rc == GB_OK && json != NULL, "gb_get_head_info after first commit");
  if (json) {
    printf("  head info: %s\n", json);
    CHECK(strstr(json, "\"branch\":\"main\"") != NULL, "gb_init'd repo's first commit lands on branch main");
    gb_free_string(json);
  }

  gb_global_shutdown();

  printf("\n%s (%d failures)\n", failures == 0 ? "ALL PASS" : "SOME FAILED", failures);
  return failures == 0 ? 0 : 1;
}
