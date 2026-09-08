import 'package:flutter_test/flutter_test.dart';
import 'package:mi_diario/main.dart';

void main() {
  testWidgets('muestra un error local sin depender de autorización', (
    tester,
  ) async {
    const message = 'No se pudo abrir el diario de prueba';

    await tester.pumpWidget(
      const MiDiarioApp(startupError: message),
    );

    expect(find.text(message), findsOneWidget);
  });
}
