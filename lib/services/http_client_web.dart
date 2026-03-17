import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

Future<void> clearPersistedCookies() async {}

http.Client createHttpClient() {
  final client = BrowserClient();
  client.withCredentials = true;
  return client;
}
