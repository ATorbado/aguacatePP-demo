import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:maquinaria_m/services/bounded_request.dart';

class HangingClient extends http.BaseClient {
  final response = Completer<http.StreamedResponse>();
  int sends = 0;
  int closes = 0;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    sends++;
    return response.future;
  }

  @override
  void close() {
    closes++;
  }
}

void main() {
  testWidgets('corta una conexion colgada a los 20 segundos sin repetirla', (
    tester,
  ) async {
    final client = HangingClient();
    var completed = false;
    final result = http.runWithClient(
      () => boundedRequest(
        'POST',
        Uri.parse('https://example.test/logs'),
        body: '{}',
      ),
      () => client,
    );
    final checked = expectLater(result, throwsA(isA<TimeoutException>()));
    result.then(
      (_) {
        completed = true;
      },
      onError: (Object _) {
        completed = true;
      },
    );
    await tester.pump();
    expect(client.sends, 1);
    await tester.pump(const Duration(seconds: 19));
    expect(completed, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await checked;
    expect(completed, isTrue);
    expect(client.closes, 1);
    await tester.pump(const Duration(seconds: 40));
    expect(client.sends, 1);
  });

  testWidgets('autorizacion tardia no inicia una peticion vencida', (
    tester,
  ) async {
    final client = HangingClient();
    final headers = Completer<Map<String, String>>();
    final result = http.runWithClient(
      () => boundedRequest(
        'POST',
        Uri.parse('https://example.test/logs'),
        headers: headers.future,
      ),
      () => client,
    );
    final checked = expectLater(result, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 20));
    await checked;
    headers.complete({});
    await tester.pump();
    expect(client.sends, 0);
    expect(client.closes, 1);
  });

  testWidgets('limita tambien la lectura de un cuerpo que no termina', (
    tester,
  ) async {
    final client = HangingClient();
    final body = StreamController<List<int>>();
    final result = http.runWithClient(
      () => boundedRequest('GET', Uri.parse('https://example.test/list')),
      () => client,
    );
    final checked = expectLater(result, throwsA(isA<TimeoutException>()));
    await tester.pump();
    client.response.complete(http.StreamedResponse(body.stream, 200));
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    await checked;
    expect(client.closes, 1);
    await body.close();
  });
}
