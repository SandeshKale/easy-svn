import 'dart:async';
import 'dart:convert';

import 'package:easy_svn/features/auth/github_oauth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Backs FlutterSecureStorage with an in-memory map instead of a
    // real platform channel (flutter_secure_storage's own supported
    // test hook — see its `setMockInitialValues`).
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('signIn', () {
    test('throws when client id/secret are not configured', () async {
      final service = GitHubOAuthService(clientId: '', clientSecret: 'x');
      await expectLater(
        service.signIn(),
        throwsA(isA<GitHubOAuthException>()),
      );
    });

    test(
      'happy path: launches authorize URL, waits for callback, '
      'exchanges code, stores token',
      () async {
        final linkController = StreamController<Uri>.broadcast();
        addTearDown(linkController.close);

        Uri? launchedUri;
        LaunchMode? launchedMode;

        final client = MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url,
            Uri.parse('https://github.com/login/oauth/access_token'),
          );
          final body = Uri.splitQueryString(request.body);
          expect(body['grant_type'], 'authorization_code');
          expect(body['code'], 'the-auth-code');
          expect(body['client_id'], 'client123');
          expect(body['client_secret'], 'secret456');
          expect(body['code_verifier'], isNotEmpty);
          return http.Response(
            jsonEncode({'access_token': 'gho_faketoken'}),
            200,
          );
        });

        final service = GitHubOAuthService(
          clientId: 'client123',
          clientSecret: 'secret456',
          uriLinkStream: linkController.stream,
          httpClient: client,
          launcher: (uri, {mode = LaunchMode.platformDefault}) async {
            launchedUri = uri;
            launchedMode = mode;
            // Simulate the browser redirecting back after the user
            // approves — echo the `state` param GitHubOAuthService
            // generated so the CSRF check passes.
            final state = uri.queryParameters['state']!;
            scheduleMicrotask(() {
              linkController.add(
                Uri.parse(
                  'gitclient://oauth/callback?code=the-auth-code&state=$state',
                ),
              );
            });
            return true;
          },
        );

        final token = await service.signIn();

        expect(token, 'gho_faketoken');
        expect(launchedMode, LaunchMode.externalApplication);
        expect(launchedUri?.scheme, 'https');
        expect(launchedUri?.host, 'github.com');
        expect(launchedUri?.path, '/login/oauth/authorize');
        expect(launchedUri?.queryParameters['client_id'], 'client123');
        expect(launchedUri?.queryParameters['scope'], 'repo');
        expect(
          launchedUri?.queryParameters['code_challenge_method'],
          'S256',
        );
        expect(await service.readStoredToken(), 'gho_faketoken');
      },
    );

    test('rejects a callback whose state does not match (CSRF)', () async {
      final linkController = StreamController<Uri>.broadcast();
      addTearDown(linkController.close);

      final service = GitHubOAuthService(
        clientId: 'client123',
        clientSecret: 'secret456',
        uriLinkStream: linkController.stream,
        httpClient: MockClient((_) async => http.Response('', 500)),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          scheduleMicrotask(() {
            linkController.add(
              Uri.parse(
                'gitclient://oauth/callback?code=abc&state=not-the-real-state',
              ),
            );
          });
          return true;
        },
      );

      await expectLater(
        service.signIn(),
        throwsA(
          isA<GitHubOAuthException>().having(
            (e) => e.message,
            'message',
            contains('state mismatch'),
          ),
        ),
      );
    });

    test('surfaces an error= callback param as an exception', () async {
      final linkController = StreamController<Uri>.broadcast();
      addTearDown(linkController.close);

      final service = GitHubOAuthService(
        clientId: 'client123',
        clientSecret: 'secret456',
        uriLinkStream: linkController.stream,
        httpClient: MockClient((_) async => http.Response('', 500)),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          final state = uri.queryParameters['state']!;
          scheduleMicrotask(() {
            linkController.add(
              Uri.parse(
                'gitclient://oauth/callback?error=access_denied'
                '&error_description=User+declined&state=$state',
              ),
            );
          });
          return true;
        },
      );

      await expectLater(
        service.signIn(),
        throwsA(
          isA<GitHubOAuthException>().having(
            (e) => e.message,
            'message',
            'User declined',
          ),
        ),
      );
    });

    test('throws when the system browser fails to launch', () async {
      final service = GitHubOAuthService(
        clientId: 'client123',
        clientSecret: 'secret456',
        uriLinkStream: const Stream<Uri>.empty(),
        httpClient: MockClient((_) async => http.Response('', 500)),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async => false,
      );

      await expectLater(
        service.signIn(),
        throwsA(
          isA<GitHubOAuthException>().having(
            (e) => e.message,
            'message',
            contains('browser'),
          ),
        ),
      );
    });

    test('throws when GitHub returns an error in the token response', () async {
      final linkController = StreamController<Uri>.broadcast();
      addTearDown(linkController.close);

      final service = GitHubOAuthService(
        clientId: 'client123',
        clientSecret: 'secret456',
        uriLinkStream: linkController.stream,
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'bad_verification_code',
              'error_description': 'The code passed is incorrect or expired.',
            }),
            200,
          ),
        ),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          final state = uri.queryParameters['state']!;
          scheduleMicrotask(() {
            linkController.add(
              Uri.parse(
                'gitclient://oauth/callback?code=abc&state=$state',
              ),
            );
          });
          return true;
        },
      );

      await expectLater(
        service.signIn(),
        throwsA(
          isA<GitHubOAuthException>().having(
            (e) => e.message,
            'message',
            'The code passed is incorrect or expired.',
          ),
        ),
      );
    });

    test('throws on a non-200 token exchange response', () async {
      final linkController = StreamController<Uri>.broadcast();
      addTearDown(linkController.close);

      final service = GitHubOAuthService(
        clientId: 'client123',
        clientSecret: 'secret456',
        uriLinkStream: linkController.stream,
        httpClient: MockClient((_) async => http.Response('', 503)),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          final state = uri.queryParameters['state']!;
          scheduleMicrotask(() {
            linkController.add(
              Uri.parse(
                'gitclient://oauth/callback?code=abc&state=$state',
              ),
            );
          });
          return true;
        },
      );

      await expectLater(
        service.signIn(),
        throwsA(
          isA<GitHubOAuthException>().having(
            (e) => e.message,
            'message',
            contains('503'),
          ),
        ),
      );
    });

    test('ignores deep links for other schemes/hosts', () async {
      final linkController = StreamController<Uri>.broadcast();
      addTearDown(linkController.close);

      final service = GitHubOAuthService(
        clientId: 'client123',
        clientSecret: 'secret456',
        uriLinkStream: linkController.stream,
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode({'access_token': 'tok'}), 200),
        ),
        launcher: (uri, {mode = LaunchMode.platformDefault}) async {
          final state = uri.queryParameters['state']!;
          scheduleMicrotask(() {
            linkController
              ..add(Uri.parse('https://example.com/not-us'))
              ..add(Uri.parse('gitclient://somethingelse?code=x'))
              ..add(
                Uri.parse('gitclient://oauth/callback?code=abc&state=$state'),
              );
          });
          return true;
        },
      );

      expect(await service.signIn(), 'tok');
    });
  });

  group('readStoredToken / signOut', () {
    test('returns null when nothing has been stored', () async {
      final service = GitHubOAuthService();
      expect(await service.readStoredToken(), isNull);
    });

    test('signOut clears a previously stored token', () async {
      FlutterSecureStorage.setMockInitialValues({
        'github_token': 'preexisting',
      });
      final service = GitHubOAuthService();
      expect(await service.readStoredToken(), 'preexisting');

      await service.signOut();
      expect(await service.readStoredToken(), isNull);
    });
  });
}
