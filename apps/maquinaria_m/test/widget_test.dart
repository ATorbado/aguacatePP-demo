import 'package:flutter_test/flutter_test.dart';
import 'package:maquinaria_m/main.dart';

void main() {
  testWidgets('la demostración abre sin autorización', (tester) async {
    await tester.pumpWidget(const MaquinariaMApp());
    await tester.pump();
    expect(find.text('Aplicación bloqueada'), findsNothing);
  });
}
