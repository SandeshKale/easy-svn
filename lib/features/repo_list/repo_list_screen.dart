import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/providers.dart';
import '../../data/db/app_database.dart';
import '../../shared/widgets/progress_dialog.dart';
import '../auth/auth_controller.dart';
import '../clone/clone_repo_screen.dart';
import '../file_browser/file_browser_screen.dart';

class RepoListScreen extends ConsumerWidget {
  const RepoListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reposAsync = ref.watch(reposProvider);
    final isOnline = ref.watch(isOnlineProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('easy-svn'),
        actions: [
          if (!isOnline)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Tooltip(
                message: 'Offline — showing cached repositories',
                child: Icon(Icons.cloud_off),
              ),
            ),
          IconButton(
            icon: Icon(authState is AuthSignedIn ? Icons.logout : Icons.login),
            tooltip: authState is AuthSignedIn
                ? 'Sign out of GitHub'
                : 'Sign in to GitHub',
            onPressed: () async {
              final controller = ref.read(authControllerProvider.notifier);
              if (authState is AuthSignedIn) {
                await controller.signOut();
              } else {
                await controller.signIn();
              }
            },
          ),
        ],
      ),
      body: reposAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load repositories: $error')),
        data: (repos) {
          if (repos.isEmpty) {
            return const _EmptyState();
          }
          return ListView.builder(
            itemCount: repos.length,
            itemBuilder: (context, index) => _RepoTile(repo: repos[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add repo'),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CloneRepoScreen())),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Theme.of(context).disabledColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No repositories yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap "Add repo" to clone one from GitHub.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RepoTile extends ConsumerWidget {
  const _RepoTile({required this.repo});

  final Repo repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Slidable(
      key: ValueKey(repo.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            icon: Icons.arrow_downward,
            label: 'Pull',
            backgroundColor: Colors.blue,
            onPressed: (context) => _pull(context, ref),
          ),
          SlidableAction(
            icon: Icons.arrow_upward,
            label: 'Push',
            backgroundColor: Colors.green,
            onPressed: (context) => _push(context, ref),
          ),
          SlidableAction(
            icon: Icons.delete,
            label: 'Delete',
            backgroundColor: Colors.red,
            onPressed: (context) => _delete(context, ref),
          ),
        ],
      ),
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.source)),
        title: Text(repo.name),
        subtitle: Text(_subtitle()),
        trailing: repo.unpushedCommits > 0
            ? Badge(
                label: Text('${repo.unpushedCommits}'),
                child: const Icon(Icons.arrow_upward, size: 18),
              )
            : null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FileBrowserScreen(repo: repo)),
        ),
      ),
    );
  }

  String _subtitle() {
    final branch = repo.defaultBranch;
    final synced = repo.lastSyncedAt;
    if (synced == null) return branch;
    return '$branch • synced ${DateFormat.yMd().add_jm().format(synced)}';
  }

  Future<void> _pull(BuildContext context, WidgetRef ref) async {
    final token = await ref.read(authTokenProvider.future);
    if (!context.mounted) return;
    await runWithProgressDialog(
      context: context,
      title: 'Pulling ${repo.name}…',
      operation: (onProgress) => ref
          .read(repoManagerProvider)
          .pull(repo: repo, token: token, onProgress: onProgress),
    );
  }

  Future<void> _push(BuildContext context, WidgetRef ref) async {
    final token = await ref.read(authTokenProvider.future);
    if (!context.mounted) return;
    await runWithProgressDialog(
      context: context,
      title: 'Pushing ${repo.name}…',
      operation: (onProgress) => ref
          .read(repoManagerProvider)
          .push(repo: repo, token: token, onProgress: onProgress),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete repository?'),
        content: Text(
          'This removes "${repo.name}" and all local files. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(repoManagerProvider).deleteRepo(repo);
    }
  }
}
