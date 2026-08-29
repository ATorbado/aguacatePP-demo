import 'package:mailer/smtp_server.dart';

/// Configuración de correo fuera del código fuente.
///
/// IMPORTANTE: `--dart-define` evita publicar credenciales en el repositorio,
/// pero los valores siguen formando parte del binario. Para una protección
/// completa, el envío debe realizarse desde un backend autenticado.
class EmailConfig {
  static const bool demoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: true,
  );
  static const String smtpUser = String.fromEnvironment('SMTP_USER');
  static const String smtpAppPassword =
      String.fromEnvironment('SMTP_APP_PASSWORD');
  static const String _sender = String.fromEnvironment('SMTP_FROM');

  static const String _to = String.fromEnvironment(
    'EMAIL_TO',
  );

  static const String _cc = String.fromEnvironment(
    'EMAIL_CC',
  );

  static String get senderAddress =>
      _sender.trim().isEmpty ? smtpUser.trim() : _sender.trim();

  static List<String> get toRecipients => _parseAddresses(_to);
  static List<String> get ccRecipients => _parseAddresses(_cc);

  static bool get isConfigured =>
      _isValidEmail(smtpUser.trim()) &&
      smtpAppPassword.trim().isNotEmpty &&
      _isValidEmail(senderAddress) &&
      toRecipients.isNotEmpty;

  static SmtpServer createSmtpServer() {
    if (!isConfigured) {
      throw StateError(
        'Correo no configurado. Define SMTP_USER y SMTP_APP_PASSWORD.',
      );
    }
    return gmail(smtpUser.trim(), smtpAppPassword.trim());
  }

  static bool isAllowedRecipient(String address) {
    final normalized = address.trim().toLowerCase();
    return <String>{
      ...toRecipients.map((e) => e.toLowerCase()),
      ...ccRecipients.map((e) => e.toLowerCase()),
    }.contains(normalized);
  }

  static List<String> _parseAddresses(String raw) {
    return raw
        .split(',')
        .map((value) => value.trim())
        .where(_isValidEmail)
        .toSet()
        .toList(growable: false);
  }

  static bool _isValidEmail(String value) {
    return RegExp(
      r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }
}
