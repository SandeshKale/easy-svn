import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:easy_svn/features/auth/pkce.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PkcePair.generate', () {
    test('verifier is 128 chars from the RFC 7636 unreserved charset', () {
      final pair = PkcePair.generate();
      expect(pair.codeVerifier.length, 128);
      expect(
        RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(pair.codeVerifier),
        isTrue,
        reason: 'verifier contained a character outside [A-Za-z0-9-._~]',
      );
    });

    test('challenge is BASE64URL(SHA256(verifier)) with no padding', () {
      final pair = PkcePair.generate();
      final expected = base64UrlEncode(
        sha256.convert(utf8.encode(pair.codeVerifier)).bytes,
      ).replaceAll('=', '');
      expect(pair.codeChallenge, expected);
      expect(pair.codeChallenge, isNot(contains('=')));
    });

    test('successive calls produce different verifiers', () {
      final a = PkcePair.generate();
      final b = PkcePair.generate();
      expect(a.codeVerifier, isNot(equals(b.codeVerifier)));
      expect(a.codeChallenge, isNot(equals(b.codeChallenge)));
    });
  });

  group('generateOAuthState', () {
    test('is non-empty and URL-safe', () {
      final state = generateOAuthState();
      expect(state, isNotEmpty);
      expect(RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(state), isTrue);
    });

    test('successive calls differ', () {
      final states = List.generate(20, (_) => generateOAuthState());
      expect(states.toSet().length, states.length);
    });
  });
}
