import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// RFC 7636 PKCE parameters for one in-flight OAuth2 authorization
/// attempt (plan §9 step 1).
class PkcePair {
  PkcePair._(this.codeVerifier, this.codeChallenge);

  final String codeVerifier;
  final String codeChallenge;

  static const _allowedChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  factory PkcePair.generate() {
    final random = Random.secure();
    final verifier = String.fromCharCodes(
      List.generate(
        128,
        (_) => _allowedChars.codeUnitAt(random.nextInt(_allowedChars.length)),
      ),
    );
    final challenge = base64UrlEncode(
      sha256.convert(utf8.encode(verifier)).bytes,
    ).replaceAll('=', '');
    return PkcePair._(verifier, challenge);
  }
}

/// Cryptographically random `state` parameter, used to reject
/// callbacks that don't match the authorization request we sent
/// (CSRF protection for the OAuth redirect).
String generateOAuthState() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}
