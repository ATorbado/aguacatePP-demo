import 'package:flutter_test/flutter_test.dart';
import 'package:maquinaria_m/main.dart';
import 'package:maquinaria_m/remote_security.dart';

void main() {
  testWidgets('muestra el bloqueo de seguridad', (tester) async {
    const message = 'Acceso bloqueado para la prueba';

    await tester.pumpWidget(
      const MaquinariaMApp(
        securityResult: RemoteSecurityResult(
          status: RemoteSecurityStatus.error,
          message: message,
        ),
      ),
    );

    expect(find.text(message), findsOneWidget);
  });
}
