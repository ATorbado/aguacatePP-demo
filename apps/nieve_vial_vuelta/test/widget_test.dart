import 'package:flutter_test/flutter_test.dart';
import 'package:nieve_vial_vuelta/main.dart';

void main() {
  testWidgets('la demostración abre sin autorización', (tester) async {
    await tester.pumpWidget(
      App2ConfirmacionNieve(
        api: ApiClient(baseUrl: 'https://example.invalid', apiToken: ''),
      ),
    );

    expect(find.text('Nieve Vial Vuelta'), findsOneWidget);
  });
}
