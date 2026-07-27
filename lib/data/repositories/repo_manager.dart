import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:git2_bridge/git2_bridge.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/app_database.dart';

/// Where cloned repositories live on disk (plan §10: `AppDocuments/repos/`).
Future<Directory> reposRootDirectory() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'repos'));
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// Derives a filesystem-safe local directory name from a repo's
/// remote URL, e.g. `https://github.com/foo/bar.git` -> `bar`.
String repoNameFromUrl(String url) {
  var name = url.trim();
  if (name.endsWith('/')) name = name.substring(0, name.length - 1);
  name = name.split('/').last;
  if (name.endsWith('.git')) name = name.substring(0, name.length - 4);
  return name.isEmpty ? 'repository' : name;
}

/// Orchestrates clone/pull/push/commit against both the native git
/// bridge (the actual repository on disk) and the Drift `repos` table
/// (UI-facing metadata: name, sync status, unpushed count). Every
/// public method here is the single place a screen should call for a
/// given operation — screens never call [Git2Bridge] directly.
class RepoManager {
  RepoManager(this._db);

  final AppDatabase _db;

  Stream<List<Repo>> watchRepos() => _db.select(_db.repos).watch();

  Future<Repo> cloneRepository({
    required String url,
    String? token,
    bool shallow = true,
    GbProgressCallback? onProgress,
  }) async {
    final root = await reposRootDirectory();
    var name = repoNameFromUrl(url);
    var localPath = p.join(root.path, name);
    var suffix = 1;
    while (Directory(localPath).existsSync()) {
      suffix++;
      localPath = p.join(root.path, '$name-$suffix');
    }

    await Git2Bridge.clone(
      url: url,
      path: localPath,
      token: token,
      shallow: shallow,
      onProgress: onProgress,
    );

    final head = await Git2Bridge.getHeadInfo(localPath);
    final id = await _db
        .into(_db.repos)
        .insert(
          ReposCompanion.insert(
            name: name,
            localPath: localPath,
            remoteUrl: url,
            defaultBranch: head != null
                ? Value(head.branch)
                : const Value('main'),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
    return (_db.select(_db.repos)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> pull({
    required Repo repo,
    String? token,
    GbProgressCallback? onProgress,
  }) async {
    await Git2Bridge.pull(
      path: repo.localPath,
      token: token,
      onProgress: onProgress,
    );
    await _refreshSyncMetadata(repo);
  }

  Future<void> push({
    required Repo repo,
    String? token,
    GbProgressCallback? onProgress,
  }) async {
    await Git2Bridge.push(
      path: repo.localPath,
      token: token,
      onProgress: onProgress,
    );
    await _refreshSyncMetadata(repo);
  }

  Future<void> stage(Repo repo, String filePath) =>
      Git2Bridge.stage(repoPath: repo.localPath, filePath: filePath);

  Future<void> unstage(Repo repo, String filePath) =>
      Git2Bridge.unstage(repoPath: repo.localPath, filePath: filePath);

  Future<void> commit({
    required Repo repo,
    required String message,
    required String authorName,
    required String authorEmail,
  }) async {
    await Git2Bridge.commit(
      repoPath: repo.localPath,
      message: message,
      authorName: authorName,
      authorEmail: authorEmail,
    );
    await _refreshSyncMetadata(repo);
  }

  Future<List<GbStatusEntry>> status(Repo repo) =>
      Git2Bridge.getStatus(repo.localPath);

  Future<List<GbTreeEntry>> fileTree(Repo repo, {String relPath = ''}) =>
      Git2Bridge.getFileTree(repoPath: repo.localPath, relPath: relPath);

  Future<void> deleteRepo(Repo repo, {bool deleteFiles = true}) async {
    await (_db.delete(_db.repos)..where((t) => t.id.equals(repo.id))).go();
    if (deleteFiles) {
      final dir = Directory(repo.localPath);
      if (dir.existsSync()) await dir.delete(recursive: true);
    }
  }

  Future<void> _refreshSyncMetadata(Repo repo) async {
    final unpushed = await Git2Bridge.getUnpushedCount(repo.localPath);
    await (_db.update(_db.repos)..where((t) => t.id.equals(repo.id))).write(
      ReposCompanion(
        unpushedCommits: Value(unpushed),
        lastSyncedAt: Value(DateTime.now()),
      ),
    );
  }
}
