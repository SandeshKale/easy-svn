import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

sealed class AuthState {
  const AuthState();
}

class AuthIdle extends AuthState {
  const AuthIdle();
}

class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.token);
  final String token;
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

/// Drives the OAuth PKCE sign-in flow (plan §4 W6/W7) and exposes its
/// current phase for the UI to react to.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreExistingToken();
    return const AuthIdle();
  }

  Future<void> _restoreExistingToken() async {
    final token = await ref.read(gitHubOAuthServiceProvider).readStoredToken();
    if (token != null) state = AuthSignedIn(token);
  }

  Future<void> signIn() async {
    state = const AuthSigningIn();
    try {
      final token = await ref.read(gitHubOAuthServiceProvider).signIn();
      state = AuthSignedIn(token);
      ref.invalidate(authTokenProvider);
    } on Exception catch (e) {
      state = AuthError(e.toString());
    }
  }

  Future<void> signOut() async {
    await ref.read(gitHubOAuthServiceProvider).signOut();
    state = const AuthIdle();
    ref.invalidate(authTokenProvider);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
