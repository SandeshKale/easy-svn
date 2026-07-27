import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/repo_manager.dart';
import '../features/auth/github_oauth_service.dart';

/// Single app-lifetime Drift database connection.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repoManagerProvider = Provider<RepoManager>((ref) {
  return RepoManager(ref.watch(appDatabaseProvider));
});

final gitHubOAuthServiceProvider = Provider<GitHubOAuthService>((ref) {
  return GitHubOAuthService();
});

/// The full list of repos, live-updating as clones/commits/pushes
/// change their metadata (plan §4 W4: "CRUD for repo metadata").
final reposProvider = StreamProvider<List<Repo>>((ref) {
  return ref.watch(repoManagerProvider).watchRepos();
});

/// Null when signed out. Screens gate GitHub-authenticated actions
/// (clone of private repos, push, pull of private repos) on this.
final authTokenProvider = FutureProvider<String?>((ref) {
  return ref.watch(gitHubOAuthServiceProvider).readStoredToken();
});

/// Coarse online/offline signal for the repo list's offline indicator
/// (plan §7: "offline indicators").
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityProvider).valueOrNull;
  if (connectivity == null) return true; // optimistic until first event
  return connectivity.any((r) => r != ConnectivityResult.none);
});
