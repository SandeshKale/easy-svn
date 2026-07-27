import 'dart:io';

import 'package:archive/archive_io.dart';
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

/// Derives a filesystem-safe local directory name from a zip file's
/// path, e.g. `/downloads/my-repo.zip` -> `my-repo`.
String repoNameFromZipPath(String zipPath) {
  final name = p.basenameWithoutExtension(zipPath);
  return name.isEmpty ? 'imported-repo' : name;
}

/// Decodes a zip archive from [bytes].
///
/// If every entry lives under one common top-level directory — as
/// produced by GitHub's "Download ZIP" and most "zip a folder" tools —
/// that wrapper directory is stripped so the archive's real root lands
/// at the top level instead of one level deeper. [exclude], if given,
/// is called with each (already-unwrapped, `/`-separated) entry path
/// and drops it from the result when it returns true.
Archive decodeZipArchive(
  List<int> bytes, {
  bool Function(String path)? exclude,
}) {
  final decoded = ZipDecoder().decodeBytes(bytes);

  final topLevelDirs = <String>{};
  var hasRootEntry = false;
  for (final entry in decoded) {
    final normalized = entry.name.replaceAll(r'\', '/');
    final firstSlash = normalized.indexOf('/');
    if (firstSlash <= 0) {
      hasRootEntry = true;
      break;
    }
    topLevelDirs.add(normalized.substring(0, firstSlash));
  }
  final stripPrefix = (!hasRootEntry && topLevelDirs.length == 1)
      ? '${topLevelDirs.first}/'
      : null;

  // Rebuilt into a fresh Archive (rather than renaming/removing entries
  // of `decoded` in place) because Archive.removeFile looks entries up
  // by name in an internal map that's keyed by their pre-rename names —
  // mutating `entry.name` first would make later removals silently
  // no-op.
  final result = Archive();
  for (final entry in decoded) {
    var name = entry.name.replaceAll(r'\', '/');
    if (stripPrefix != null) name = name.substring(stripPrefix.length);
    if (exclude != null && exclude(name)) continue;
    entry.name = name;
    result.addFile(entry);
  }
  return result;
}

/// Orchestrates clone/pull/push/commit against both the native git
/// bridge (the actual repository on disk) and the Drift `repos` table
/// (UI-facing metadata: name, sync status, unpushed count). Every
/// public method here is the single place a screen should call for a
/// given operation — screens never call [Git2Bridge] directly.
class RepoManager {
  RepoManager(AppDatabase db) : _db = db;

  final AppDatabase _db;

  Stream<List<Repo>> watchRepos() => _db.select(_db.repos).watch();

  Future<Repo> cloneRepository({
    required String url,
    String? token,
    bool shallow = true,
    GbProgressCallback? onProgress,
  }) async {
    final root = await reposRootDirectory();
    final name = repoNameFromUrl(url);
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

  /// Extracts [zipPath] as a brand-new repo under [reposRootDirectory]
  /// (scenario: importing a standalone zip, which may or may not
  /// already contain a `.git` folder, with no prior clone required).
  /// If the zip's contents already form a git repository, that history
  /// is kept as-is; otherwise [Git2Bridge.init] creates one so the
  /// import lands with an unborn HEAD ready for an initial commit.
  Future<Repo> importZipAsNewRepo(String zipPath) async {
    final root = await reposRootDirectory();
    final baseName = repoNameFromZipPath(zipPath);
    var localPath = p.join(root.path, baseName);
    var suffix = 1;
    while (Directory(localPath).existsSync()) {
      suffix++;
      localPath = p.join(root.path, '$baseName-$suffix');
    }

    await _extractZip(zipPath, localPath);

    if (!await Git2Bridge.isRepository(localPath)) {
      await Git2Bridge.init(localPath);
    }

    final head = await Git2Bridge.getHeadInfo(localPath);
    final id = await _db
        .into(_db.repos)
        .insert(
          ReposCompanion.insert(
            name: baseName,
            localPath: localPath,
            remoteUrl: '',
            defaultBranch: head != null
                ? Value(head.branch)
                : const Value('main'),
            lastSyncedAt: Value(DateTime.now()),
          ),
        );
    return (_db.select(_db.repos)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Reconciles [zipPath] into [repo]'s existing working directory
  /// (scenario: applying a snapshot zip on top of an already-cloned
  /// repo). Files present in the zip overwrite/add their working-tree
  /// counterparts; anything under `.git` is never touched. The caller
  /// is expected to show the resulting `status()` diff so the user can
  /// selectively stage and commit only what actually changed.
  Future<void> importZipIntoRepo(Repo repo, String zipPath) => _extractZip(
    zipPath,
    repo.localPath,
    exclude: (name) => name == '.git' || name.startsWith('.git/'),
  );

  /// Decodes the zip at [zipPath] (see [decodeZipArchive]) and extracts
  /// it into [outputPath].
  Future<void> _extractZip(
    String zipPath,
    String outputPath, {
    bool Function(String normalizedName)? exclude,
  }) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = decodeZipArchive(bytes, exclude: exclude);
    await extractArchiveToDisk(archive, outputPath);
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
