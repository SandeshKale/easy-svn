import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/widgets/progress_dialog.dart';
import '../auth/auth_controller.dart';

class CloneRepoScreen extends ConsumerStatefulWidget {
  const CloneRepoScreen({super.key});

  @override
  ConsumerState<CloneRepoScreen> createState() => _CloneRepoScreenState();
}

class _CloneRepoScreenState extends ConsumerState<CloneRepoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _shallow = true;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final signedIn = authState is AuthSignedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Add repository')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!signedIn) _SignInBanner(authState: authState),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Repository URL',
                  hintText: 'https://github.com/owner/repo.git',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Enter a repository URL';
                  final uri = Uri.tryParse(v);
                  if (uri == null || !uri.isScheme('HTTPS')) {
                    return 'Must be an HTTPS URL (SSH isn\'t supported yet)';
                  }
                  return null;
                },
              ),
              SwitchListTile(
                title: const Text('Shallow clone'),
                subtitle: const Text(
                  'Faster, smaller — only the latest commit (plan §5.3)',
                ),
                value: _shallow,
                onChanged: (value) => setState(() => _shallow = value),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Clone'),
                onPressed: () => _clone(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clone(BuildContext context) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final url = _urlController.text.trim();
    final token = await ref.read(authTokenProvider.future);

    if (!context.mounted) return;
    final succeeded = await runWithProgressDialog(
      context: context,
      title: 'Cloning…',
      operation: (onProgress) => ref
          .read(repoManagerProvider)
          .cloneRepository(
            url: url,
            token: token,
            shallow: _shallow,
            onProgress: onProgress,
          ),
    );

    if (succeeded && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _SignInBanner extends ConsumerWidget {
  const _SignInBanner({required this.authState});

  final AuthState authState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Sign in to GitHub to clone private repositories and to pull/push.',
              ),
            ),
            TextButton(
              onPressed: authState is AuthSigningIn
                  ? null
                  : () => ref.read(authControllerProvider.notifier).signIn(),
              child: authState is AuthSigningIn
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
