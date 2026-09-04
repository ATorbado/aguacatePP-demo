import 'package:flutter_test/flutter_test.dart';
import 'package:inspecciones/main.dart';

void main() {
  testWidgets('muestra el formulario público con datos ficticios', (
    tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Inspecciones — Demostración'), findsOneWidget);
    expect(
      find.textContaining('no contacta con ningún servidor'),
      findsOneWidget,
    );
    expect(find.text('Responsable 1'), findsOneWidget);
    expect(find.text('Guardar y continuar'), findsOneWidget);
  });

  testWidgets('valida los campos obligatorios', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Guardar y continuar'));
    await tester.pump();

    expect(find.text('Obligatorio'), findsNWidgets(2));
  });
}
