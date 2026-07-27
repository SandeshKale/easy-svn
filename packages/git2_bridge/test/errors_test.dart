import 'package:flutter_test/flutter_test.dart';
import 'package:git2_bridge/git2_bridge.dart';

void main() {
  group('GbErrorCode.fromCode', () {
    test('maps every declared code back to its enum value', () {
      for (final value in GbErrorCode.values) {
        expect(GbErrorCode.fromCode(value.code), value);
      }
    });

    test('falls back to generic for an unrecognized code', () {
      expect(GbErrorCode.fromCode(999999), GbErrorCode.generic);
      expect(GbErrorCode.fromCode(-42), GbErrorCode.generic);
    });

    test('every code is unique (no two enum values share a code)', () {
      final codes = GbErrorCode.values.map((e) => e.code).toList();
      expect(codes.toSet().length, codes.length);
    });

    test('every userMessage is non-empty', () {
      for (final value in GbErrorCode.values) {
        expect(value.userMessage, isNotEmpty, reason: value.name);
      }
    });

    test('notFound and unbornHead are distinct codes', () {
      // Regression guard: these were once conflated under one code,
      // which made "repo does not exist" and "repo has no commits
      // yet" indistinguishable to callers (see git_bridge.h history).
      expect(GbErrorCode.notFound.code, isNot(GbErrorCode.unbornHead.code));
    });
  });

  group('throwIfError', () {
    test('does nothing for code 0', () {
      expect(() => throwIfError(0, 'irrelevant'), returnsNormally);
    });

    test(
      'throws GitBridgeException carrying the mapped code and raw message',
      () {
        try {
          throwIfError(-16, 'HTTP 401 from server');
          fail('expected throwIfError to throw');
        } on GitBridgeException catch (e) {
          expect(e.errorCode, GbErrorCode.auth);
          expect(e.nativeMessage, 'HTTP 401 from server');
          expect(e.userMessage, GbErrorCode.auth.userMessage);
        }
      },
    );

    test('unrecognized codes surface as generic', () {
      try {
        throwIfError(12345, 'mystery failure');
        fail('expected throwIfError to throw');
      } on GitBridgeException catch (e) {
        expect(e.errorCode, GbErrorCode.generic);
      }
    });
  });

  group('GitBridgeException.toString', () {
    test('includes the error code name and native message', () {
      final e = GitBridgeException(GbErrorCode.network, 'connection reset');
      expect(e.toString(), 'GitBridgeException(network): connection reset');
    });
  });
}
