import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:git2_bridge/git2_bridge.dart';

import '../../core/providers.dart';
import '../../data/db/app_database.dart';
import '../staging_commit/staging_commit_screen.dart';

/// Offline-browsable file tree for one repo (plan §4 W4/§7: "Offline
/// file tree is browsable without network connection"). Reads
/// directly from the last-checked-out working tree via
/// `gb_get_file_tree`, so no network access is ever needed here.
class FileBrowserScreen extends ConsumerWidget {
  const FileBrowserScreen({required this.repo, super.key, this.relPath = ''});

  final Repo repo;
  final String relPath;

  String get _title => relPath.isEmpty ? repo.name : relPath.split('/').last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeFuture = ref
        .read(repoManagerProvider)
        .fileTree(repo, relPath: relPath);

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Stage & commit',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => StagingCommitScreen(repo: repo),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<GbTreeEntry>>(
        future: treeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is GitBridgeException
                ? (snapshot.error! as GitBridgeException).userMessage
                : '${snapshot.error}';
            return Center(child: Text('Failed to read files: $message'));
          }
          final entries = [...?snapshot.data]
            ..sort((a, b) {
              if (a.isDirectory != b.isDirectory) {
                return a.isDirectory ? -1 : 1;
              }
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
          if (entries.isEmpty) {
            return const Center(child: Text('This folder has no commits yet.'));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: Icon(
                  entry.isDirectory ? Icons.folder : Icons.description_outlined,
                ),
                title: Text(entry.name),
                subtitle: entry.isDirectory
                    ? null
                    : Text(_formatSize(entry.size)),
                trailing: entry.isDirectory
                    ? const Icon(Icons.chevron_right)
                    : null,
                onTap: entry.isDirectory
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FileBrowserScreen(
                            repo: repo,
                            relPath: entry.path,
                          ),
                        ),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
