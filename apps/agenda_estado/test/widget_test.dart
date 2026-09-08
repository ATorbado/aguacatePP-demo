import 'package:agenda_estado/app_config.dart';
import 'package:agenda_estado/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final validConfig = AppConfig(
    backendUri: Uri(scheme: 'https', host: 'example.test', path: '/submit'),
    apiToken: 'test-token-with-enough-length',
  );

  testWidgets('bloquea una configuración de servidor insegura', (tester) async {
    await tester.pumpWidget(
      MyApp(
        config: AppConfig(
          backendUri: Uri(scheme: 'http', host: 'example.test'),
          apiToken: 'test-token-with-enough-length',
        ),
      ),
    );

    expect(find.text('Configuración pendiente'), findsOneWidget);
    expect(find.textContaining('URL HTTPS'), findsOneWidget);
  });

  testWidgets('la demostración abre sin autorización', (tester) async {
    await tester.pumpWidget(MyApp(config: validConfig));
    expect(find.text('Aplicación bloqueada'), findsNothing);
  });
}
