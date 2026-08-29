import 'package:agenda_estado/remote_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validatePolicyTimestamp', () {
    test('acepta una política firmada dentro del TTL', () {
      final result = validatePolicyTimestamp(
        policy: {'ts': '2026-07-20T10:00:00Z', 'ttlDays': 15},
        nowUtc: DateTime.utc(2026, 7, 24, 10),
        ttlDays: 15,
      );

      expect(result.status, PolicyTimestampStatus.valid);
      expect(result.expiresAt, DateTime.utc(2026, 8, 4, 10));
      expect(result.remainingDays, 11);
    });

    test('bloquea una política cuya fecha más TTL ya pasó', () {
      final result = validatePolicyTimestamp(
        policy: {'ts': '2025-10-08T10:00:00Z', 'ttlDays': 15},
        nowUtc: DateTime.utc(2026, 7, 24),
        ttlDays: 15,
      );

      expect(result.status, PolicyTimestampStatus.expired);
      expect(result.expiresAt, DateTime.utc(2025, 10, 23, 10));
    });

    test('acepta exactamente el instante de caducidad', () {
      final result = validatePolicyTimestamp(
        policy: {'ts': '2026-07-09T10:00:00Z'},
        nowUtc: DateTime.utc(2026, 7, 24, 10),
        ttlDays: 15,
      );

      expect(result.status, PolicyTimestampStatus.valid);
      expect(result.remainingDays, 0);
    });

    test('bloquea una fecha futura más de cinco minutos', () {
      final result = validatePolicyTimestamp(
        policy: {'ts': '2026-07-24T10:06:00Z'},
        nowUtc: DateTime.utc(2026, 7, 24, 10),
        ttlDays: 15,
      );

      expect(result.status, PolicyTimestampStatus.future);
    });

    test('rechaza fecha ausente, inválida o sin zona UTC', () {
      for (final policy in [
        <String, dynamic>{},
        {'ts': 'no-es-una-fecha'},
        {'ts': '2026-07-24T10:00:00'},
      ]) {
        final result = validatePolicyTimestamp(
          policy: policy,
          nowUtc: DateTime.utc(2026, 7, 24, 10),
          ttlDays: 15,
        );

        expect(result.status, PolicyTimestampStatus.missingOrInvalid);
      }
    });
  });
}
