import 'package:agenda_estado/app_config.dart';
import 'package:agenda_estado/main.dart';
import 'package:agenda_estado/remote_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final validConfig = AppConfig(
    backendUri: Uri(scheme: 'https', host: 'example.test', path: '/submit'),
    apiToken: 'test-token-with-enough-length',
  );

  testWidgets('muestra el bloqueo de seguridad', (tester) async {
    await tester.pumpWidget(
      MyApp(
        securityResult: const RemoteSecurityResult(
          status: RemoteSecurityStatus.blockedVersion,
          message: 'Versión no autorizada.',
        ),
        config: validConfig,
      ),
    );

    expect(find.text('Aplicación bloqueada'), findsOneWidget);
    expect(find.text('Versión no autorizada.'), findsOneWidget);
  });

  testWidgets('bloquea una configuración de servidor insegura', (tester) async {
    await tester.pumpWidget(
      MyApp(
        securityResult: const RemoteSecurityResult(
          status: RemoteSecurityStatus.allowed,
          message: 'Aplicación autorizada.',
        ),
        config: AppConfig(
          backendUri: Uri(scheme: 'http', host: 'example.test'),
          apiToken: 'test-token-with-enough-length',
        ),
      ),
    );

    expect(find.text('Configuración pendiente'), findsOneWidget);
    expect(find.textContaining('URL HTTPS'), findsOneWidget);
  });
}
