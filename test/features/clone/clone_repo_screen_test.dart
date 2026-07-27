import 'package:drift/native.dart';
import 'package:easy_svn/core/providers.dart';
import 'package:easy_svn/data/db/app_database.dart';
import 'package:easy_svn/data/repositories/repo_manager.dart';
import 'package:easy_svn/features/auth/auth_controller.dart';
import 'package:easy_svn/features/clone/clone_repo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:git2_bridge/git2_bridge.dart';

class _FixedAuthController extends AuthController {
  _FixedAuthController(this._state);
  final AuthState _state;

  @override
  AuthState build() => _state;
}

/// Stands in for the real [RepoManager] so widget tests never touch
/// the native git2_bridge FFI (which has no compiled library loaded
/// in a plain `flutter test` run) or GitHub's network.
class _FakeRepoManager extends RepoManager {
  _FakeRepoManager(super.db);

  String? lastClonedUrl;

  @override
  Future<Repo> cloneRepository({
    required String url,
    String? token,
    bool shallow = true,
    GbProgressCallback? onProgress,
  }) async {
    lastClonedUrl = url;
    onProgress?.call(
      const GbProgress(
        percent: 100,
        message: 'done',
        bytesReceived: 0,
        totalObjects: 0,
        receivedObjects: 0,
      ),
    );
    return Repo(
      id: 1,
      name: 'fake-repo',
      localPath: '/tmp/fake-repo',
      remoteUrl: url,
      defaultBranch: 'main',
      unpushedCommits: 0,
      createdAt: DateTime.now(),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required AuthState authState,
  _FakeRepoManager? fakeRepoManager,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _FixedAuthController(authState),
        ),
        authTokenProvider.overrideWith((ref) async => null),
        if (fakeRepoManager != null)
          repoManagerProvider.overrideWithValue(fakeRepoManager),
      ],
      child: const MaterialApp(home: CloneRepoScreen()),
    ),
  );
}

void main() {
  group('CloneRepoScreen validation', () {
    testWidgets('shows an error for an empty URL', (tester) async {
      await _pump(tester, authState: const AuthIdle());
      await tester.tap(find.widgetWithText(FilledButton, 'Clone'));
      await tester.pump();

      expect(find.text('Enter a repository URL'), findsOneWidget);
    });

    testWidgets('rejects a non-HTTPS URL', (tester) async {
      await _pump(tester, authState: const AuthIdle());
      await tester.enterText(
        find.byType(TextFormField),
        'git@github.com:octocat/Hello-World.git',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Clone'));
      await tester.pump();

      expect(
        find.text("Must be an HTTPS URL (SSH isn't supported yet)"),
        findsOneWidget,
      );
    });

    testWidgets('accepts a valid HTTPS URL and hands it to RepoManager', (
      tester,
    ) async {
      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(testDb.close);
      final fakeRepoManager = _FakeRepoManager(testDb);

      await _pump(
        tester,
        authState: const AuthIdle(),
        fakeRepoManager: fakeRepoManager,
      );
      await tester.enterText(
        find.byType(TextFormField),
        'https://github.com/octocat/Hello-World.git',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Clone'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a repository URL'), findsNothing);
      expect(
        find.text("Must be an HTTPS URL (SSH isn't supported yet)"),
        findsNothing,
      );
      expect(
        fakeRepoManager.lastClonedUrl,
        'https://github.com/octocat/Hello-World.git',
      );
      // Successful clone pops CloneRepoScreen back off the stack.
      expect(find.byType(CloneRepoScreen), findsNothing);
    });
  });

  group('CloneRepoScreen sign-in banner', () {
    testWidgets('is shown when signed out', (tester) async {
      await _pump(tester, authState: const AuthIdle());
      expect(
        find.textContaining('Sign in to GitHub to clone'),
        findsOneWidget,
      );
    });

    testWidgets('is hidden once signed in', (tester) async {
      await _pump(tester, authState: const AuthSignedIn('tok_123'));
      expect(find.textContaining('Sign in to GitHub to clone'), findsNothing);
    });

    testWidgets('shows a spinner while signing in', (tester) async {
      await _pump(tester, authState: const AuthSigningIn());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('CloneRepoScreen shallow clone toggle', () {
    testWidgets('defaults to on and can be switched off', (tester) async {
      await _pump(tester, authState: const AuthIdle());

      final switchFinder = find.byType(Switch);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pump();

      expect(tester.widget<Switch>(switchFinder).value, isFalse);
    });
  });
}
