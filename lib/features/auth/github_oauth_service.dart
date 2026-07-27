import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'pkce.dart';

const _secureStorageTokenKey = 'github_token';
const _redirectUri = 'gitclient://oauth/callback';
const _authorizeUrl = 'https://github.com/login/oauth/authorize';
const _tokenUrl = 'https://github.com/login/oauth/access_token';

/// GitHub OAuth App credentials. GitHub's classic OAuth Apps require a
/// client *secret* for the token exchange even when the authorization
/// request itself uses PKCE — unlike a "pure" public-client PKCE flow,
/// this secret ends up embedded in the compiled app binary, which is
/// a known, GitHub-imposed limitation for mobile clients (not
/// something this app can avoid while using OAuth Apps). Passed at
/// build time so it's never committed to source control:
///
///   flutter run \
///     --dart-define=GITHUB_CLIENT_ID=... \
///     --dart-define=GITHUB_CLIENT_SECRET=...
///
/// See plan §9 and README.md "GitHub OAuth App setup".
class GitHubOAuthConfig {
  static const clientId = String.fromEnvironment('GITHUB_CLIENT_ID');
  static const clientSecret = String.fromEnvironment('GITHUB_CLIENT_SECRET');

  static bool get isConfigured =>
      clientId.isNotEmpty && clientSecret.isNotEmpty;
}

class GitHubOAuthException implements Exception {
  GitHubOAuthException(this.message);
  final String message;
  @override
  String toString() => 'GitHubOAuthException: $message';
}

/// Drives the full PKCE authorization-code flow (plan §9) and persists
/// the resulting access token in flutter_secure_storage.
class GitHubOAuthService {
  GitHubOAuthService({
    FlutterSecureStorage? secureStorage,
    AppLinks? appLinks,
    http.Client? httpClient,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _appLinks = appLinks ?? AppLinks(),
       _httpClient = httpClient ?? http.Client();

  final FlutterSecureStorage _secureStorage;
  final AppLinks _appLinks;
  final http.Client _httpClient;

  /// Launches the system browser for GitHub's consent screen, waits
  /// for the `gitclient://oauth/callback` deep link, exchanges the
  /// returned code for an access token, and stores it. Returns the
  /// access token.
  Future<String> signIn() async {
    if (!GitHubOAuthConfig.isConfigured) {
      throw GitHubOAuthException(
        'GitHub OAuth is not configured. Pass --dart-define=GITHUB_CLIENT_ID '
        'and --dart-define=GITHUB_CLIENT_SECRET (see README.md).',
      );
    }

    final pkce = PkcePair.generate();
    final state = generateOAuthState();

    final authorizeUri = Uri.parse(_authorizeUrl).replace(
      queryParameters: {
        'client_id': GitHubOAuthConfig.clientId,
        'redirect_uri': _redirectUri,
        'scope': 'repo',
        'state': state,
        'code_challenge': pkce.codeChallenge,
        'code_challenge_method': 'S256',
      },
    );

    final callbackFuture = _waitForCallback(expectedState: state);

    final launched = await launchUrl(
      authorizeUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw GitHubOAuthException('Could not open the system browser.');
    }

    final code = await callbackFuture.timeout(
      const Duration(minutes: 5),
      onTimeout: () => throw GitHubOAuthException('Sign-in timed out.'),
    );

    final token = await _exchangeCodeForToken(code, pkce.codeVerifier);
    await _secureStorage.write(key: _secureStorageTokenKey, value: token);
    return token;
  }

  Future<String> _waitForCallback({required String expectedState}) async {
    final completer = Completer<String>();
    late final StreamSubscription<Uri> sub;
    sub = _appLinks.uriLinkStream.listen(
      (uri) {
        if (uri.scheme != 'gitclient' || uri.host != 'oauth') return;
        final params = uri.queryParameters;
        final error = params['error'];
        if (error != null) {
          sub.cancel();
          if (!completer.isCompleted) {
            completer.completeError(
              GitHubOAuthException(params['error_description'] ?? error),
            );
          }
          return;
        }
        final returnedState = params['state'];
        final code = params['code'];
        if (returnedState != expectedState) {
          sub.cancel();
          if (!completer.isCompleted) {
            completer.completeError(
              GitHubOAuthException(
                'OAuth state mismatch — possible CSRF, aborting sign-in.',
              ),
            );
          }
          return;
        }
        if (code == null) {
          sub.cancel();
          if (!completer.isCompleted) {
            completer.completeError(
              GitHubOAuthException('No authorization code in callback.'),
            );
          }
          return;
        }
        sub.cancel();
        if (!completer.isCompleted) completer.complete(code);
      },
      onError: (Object e) {
        if (!completer.isCompleted) {
          completer.completeError(GitHubOAuthException('Deep link error: $e'));
        }
      },
    );
    return completer.future;
  }

  Future<String> _exchangeCodeForToken(String code, String codeVerifier) async {
    final response = await _httpClient.post(
      Uri.parse(_tokenUrl),
      headers: const {'Accept': 'application/json'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': GitHubOAuthConfig.clientId,
        'client_secret': GitHubOAuthConfig.clientSecret,
        'code_verifier': codeVerifier,
      },
    );

    if (response.statusCode != 200) {
      throw GitHubOAuthException(
        'Token exchange failed (HTTP ${response.statusCode}).',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final error = body['error'] as String?;
    if (error != null) {
      throw GitHubOAuthException(
        (body['error_description'] as String?) ?? error,
      );
    }
    final token = body['access_token'] as String?;
    if (token == null) {
      throw GitHubOAuthException('No access_token in GitHub response.');
    }
    return token;
  }

  Future<String?> readStoredToken() =>
      _secureStorage.read(key: _secureStorageTokenKey);

  Future<void> signOut() => _secureStorage.delete(key: _secureStorageTokenKey);
}
