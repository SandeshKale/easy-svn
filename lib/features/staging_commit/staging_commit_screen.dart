import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:git2_bridge/git2_bridge.dart';

import '../../core/providers.dart';
import '../../data/db/app_database.dart';

/// Stage/unstage files and author a commit (plan §4 W5/W10: "staging
/// UI using git_status_list_new", "commit flow: signature + message +
/// git_commit_create", "staged/unstaged split view").
///
/// Files are edited externally (plan §1 Scope Out: "In-app file
/// editing") — this screen only reflects what `gb_get_status` already
/// sees on disk; pull-to-refresh re-reads it after an external edit.
class StagingCommitScreen extends ConsumerStatefulWidget {
  const StagingCommitScreen({required this.repo, super.key});

  final Repo repo;

  @override
  ConsumerState<StagingCommitScreen> createState() =>
      _StagingCommitScreenState();
}

class _StagingCommitScreenState extends ConsumerState<StagingCommitScreen> {
  late Future<List<GbStatusEntry>> _statusFuture;
  final _messageController = TextEditingController();
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _statusFuture = ref.read(repoManagerProvider).status(widget.repo);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _statusFuture = ref.read(repoManagerProvider).status(widget.repo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commit — ${widget.repo.name}')),
      body: FutureBuilder<List<GbStatusEntry>>(
        future: _statusFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is GitBridgeException
                ? (snapshot.error! as GitBridgeException).userMessage
                : '${snapshot.error}';
            return Center(child: Text('Failed to read status: $message'));
          }
          final entries = snapshot.data ?? const [];
          final staged = entries.where((e) => e.staged).toList();
          final unstaged = entries.where((e) => !e.staged).toList();

          if (entries.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text('Working tree clean — nothing to commit.'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              children: [
                if (unstaged.isNotEmpty)
                  _StatusSection(
                    title: 'Unstaged (${unstaged.length})',
                    entries: unstaged,
                    actionIcon: Icons.add,
                    actionTooltip: 'Stage',
                    onAction: _stage,
                  ),
                if (staged.isNotEmpty)
                  _StatusSection(
                    title: 'Staged (${staged.length})',
                    entries: staged,
                    actionIcon: Icons.remove,
                    actionTooltip: 'Unstage',
                    onAction: _unstage,
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Commit message',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: _committing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Commit'),
                        onPressed: (staged.isEmpty || _committing)
                            ? null
                            : _commit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _stage(String path) async {
    await ref.read(repoManagerProvider).stage(widget.repo, path);
    _refresh();
  }

  Future<void> _unstage(String path) async {
    await ref.read(repoManagerProvider).unstage(widget.repo, path);
    _refresh();
  }

  Future<void> _commit() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a commit message first.')),
      );
      return;
    }

    final db = ref.read(appDatabaseProvider);
    final settings = await db.ensureSettingsRow();
    final authorName = settings.authorName;
    final authorEmail = settings.authorEmail;
    if (authorName == null || authorEmail == null) {
      if (!mounted) return;
      await _promptForAuthorIdentity(db);
    }
    final refreshed = await db.ensureSettingsRow();
    if (refreshed.authorName == null || refreshed.authorEmail == null) return;

    setState(() => _committing = true);
    try {
      await ref
          .read(repoManagerProvider)
          .commit(
            repo: widget.repo,
            message: message,
            authorName: refreshed.authorName!,
            authorEmail: refreshed.authorEmail!,
          );
      _messageController.clear();
      _refresh();
    } on GitBridgeException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.userMessage)));
    } finally {
      if (mounted) setState(() => _committing = false);
    }
  }

  Future<void> _promptForAuthorIdentity(AppDatabase db) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set up commit author'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true &&
        nameController.text.trim().isNotEmpty &&
        emailController.text.trim().isNotEmpty) {
      await db.ensureSettingsRow();
      await (db.update(db.userSettings)..where((t) => t.id.equals(1))).write(
        UserSettingsCompanion(
          authorName: Value(nameController.text.trim()),
          authorEmail: Value(emailController.text.trim()),
        ),
      );
    }
  }
}

class _StatusSection extends StatelessWidget {
  const _StatusSection({
    required this.title,
    required this.entries,
    required this.actionIcon,
    required this.actionTooltip,
    required this.onAction,
  });

  final String title;
  final List<GbStatusEntry> entries;
  final IconData actionIcon;
  final String actionTooltip;
  final void Function(String path) onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        ...entries.map(
          (entry) => ListTile(
            dense: true,
            leading: _StatusIcon(status: entry.status),
            title: Text(entry.path),
            trailing: IconButton(
              icon: Icon(actionIcon),
              tooltip: actionTooltip,
              onPressed: () => onAction(entry.path),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      'added' => (Icons.add_circle_outline, Colors.green),
      'deleted' => (Icons.remove_circle_outline, Colors.red),
      'renamed' => (Icons.drive_file_rename_outline, Colors.blue),
      'conflicted' => (Icons.warning_amber, Colors.orange),
      _ => (Icons.edit_outlined, Colors.amber),
    };
    return Icon(icon, color: color, size: 20);
  }
}
