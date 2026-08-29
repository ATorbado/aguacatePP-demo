import 'package:agenda_estado/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('acepta HTTPS con una credencial no vacía', () {
    final config = AppConfig(
      backendUri: Uri(scheme: 'https', host: 'example.test', path: '/submit'),
      apiToken: 'test-token-with-enough-length',
    );

    expect(config.isValid, isTrue);
  });

  test('rechaza HTTP', () {
    final config = AppConfig(
      backendUri: Uri(scheme: 'http', host: 'example.test'),
      apiToken: 'test-token-with-enough-length',
    );

    expect(config.isValid, isFalse);
    expect(config.validationError, contains('HTTPS'));
  });

  test('rechaza una credencial vacía o demasiado corta', () {
    final config = AppConfig(
      backendUri: Uri(scheme: 'https', host: 'example.test'),
      apiToken: 'short',
    );

    expect(config.isValid, isFalse);
    expect(config.validationError, contains('credencial'));
  });
}
