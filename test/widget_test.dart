// Smoke test: the repo list screen renders its empty state without
// crashing when the DB/secure-storage/connectivity plugins are
// stubbed out via provider overrides (real plugin channels aren't
// available in a plain `flutter test` run).
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_svn/core/providers.dart';
import 'package:easy_svn/features/auth/auth_controller.dart';
import 'package:easy_svn/features/repo_list/repo_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthController extends AuthController {
  @override
  AuthState build() => const AuthIdle();
}

void main() {
  testWidgets('repo list shows empty state with no repos', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reposProvider.overrideWith((ref) => Stream.value(const [])),
          connectivityProvider.overrideWith(
            (ref) => Stream.value(const [ConnectivityResult.wifi]),
          ),
          authControllerProvider.overrideWith(_FakeAuthController.new),
        ],
        child: const MaterialApp(home: RepoListScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('No repositories yet'), findsOneWidget);
    expect(find.text('Add repo'), findsOneWidget);
  });
}
