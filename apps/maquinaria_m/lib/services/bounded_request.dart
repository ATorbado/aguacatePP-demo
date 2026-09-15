import 'dart:async';
import 'package:http/http.dart' as http;

/// Limits authorization, connection and response body to one deadline.
const requestTimeout = Duration(seconds: 20);

Future<http.Response> boundedRequest(
  String method,
  Uri uri, {
  Future<Map<String, String>>? headers,
  String? body,
}) async {
  final client = http.Client();
  var finished = false;
  try {
    return await (() async {
      final resolvedHeaders =
          await (headers ?? Future.value(<String, String>{}));
      if (finished) throw TimeoutException('Request expired');
      final request = http.Request(method, uri);
      request.headers.addAll(resolvedHeaders);
      if (body != null) request.body = body;
      final response = await client.send(request);
      return http.Response.fromStream(response);
    })().timeout(requestTimeout);
  } finally {
    finished = true;
    client.close();
  }
}
