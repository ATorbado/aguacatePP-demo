import 'package:agenda_estado/retry_backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aumenta el retraso y limita el máximo', () {
    final backoff = RetryBackoff(
      delays: const [Duration(seconds: 1), Duration(seconds: 2)],
    );

    expect(backoff.nextDelay(), const Duration(seconds: 1));
    expect(backoff.nextDelay(), const Duration(seconds: 2));
    expect(backoff.nextDelay(), const Duration(seconds: 2));
  });

  test('reset vuelve al primer retraso', () {
    final backoff = RetryBackoff(
      delays: const [Duration(seconds: 1), Duration(seconds: 2)],
    );

    backoff.nextDelay();
    backoff.nextDelay();
    backoff.reset();

    expect(backoff.nextDelay(), const Duration(seconds: 1));
  });
}
