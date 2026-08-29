import 'package:flutter_test/flutter_test.dart';
import 'package:mi_diario/main.dart';
import 'package:mi_diario/remote_security.dart';

void main() {
  testWidgets('muestra el bloqueo de seguridad', (tester) async {
    const message = 'Acceso bloqueado para la prueba';

    await tester.pumpWidget(
      const MiDiarioApp(
        securityResult: RemoteSecurityResult(
          status: RemoteSecurityStatus.error,
          message: message,
        ),
      ),
    );

    expect(find.text(message), findsOneWidget);
  });
}
