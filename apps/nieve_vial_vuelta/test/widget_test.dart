import 'package:flutter_test/flutter_test.dart';
import 'package:nieve_vial_vuelta/main.dart';
import 'package:nieve_vial_vuelta/remote_security.dart';

void main() {
  testWidgets('muestra el bloqueo de seguridad', (tester) async {
    const message = 'Acceso bloqueado para la prueba';

    await tester.pumpWidget(
      App2ConfirmacionNieve(
        api: ApiClient(baseUrl: 'https://example.invalid', apiToken: ''),
        securityResult: const RemoteSecurityResult(
          status: RemoteSecurityStatus.error,
          message: message,
        ),
      ),
    );

    expect(find.text(message), findsOneWidget);
  });
}
