import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const _cookiePrefsKey = 'auth.cookies';

Future<void> clearPersistedCookies() async {
	final prefs = await SharedPreferences.getInstance();
	await prefs.remove(_cookiePrefsKey);
}

class _CookiePersistingClient extends http.BaseClient {
	final http.Client _inner;
	final Map<String, Cookie> _cookies = <String, Cookie>{};
	bool _didLoadCookies = false;

	_CookiePersistingClient()
			: _inner = IOClient(
					HttpClient()
						..connectionTimeout = const Duration(seconds: 20)
						..idleTimeout = const Duration(seconds: 20),
				);

	@override
	Future<http.StreamedResponse> send(http.BaseRequest request) async {
		await _ensureCookiesLoaded();
		if (_cookies.isNotEmpty) {
			request.headers[HttpHeaders.cookieHeader] = _cookies.values
					.map((cookie) => '${cookie.name}=${cookie.value}')
					.join('; ');
		}

		final response = await _inner.send(request);
		final setCookieHeader = response.headers[HttpHeaders.setCookieHeader];
		if (setCookieHeader != null && setCookieHeader.isNotEmpty) {
			_storeCookies(setCookieHeader);
			await _persistCookies();
		}
		return response;
	}

	Future<void> _ensureCookiesLoaded() async {
		if (_didLoadCookies) return;
		_didLoadCookies = true;
		final prefs = await SharedPreferences.getInstance();
		final raw = prefs.getStringList(_cookiePrefsKey) ?? const <String>[];
		for (final entry in raw) {
			final separator = entry.indexOf('=');
			if (separator <= 0) continue;
			final name = entry.substring(0, separator);
			final value = entry.substring(separator + 1);
			_cookies[name] = Cookie(name, value);
		}
	}

	void _storeCookies(String rawHeader) {
		for (final match in RegExp(r'(?:^|,\s*)([^=;,\s]+)=([^;,\s]+)')
				.allMatches(rawHeader)) {
			final name = match.group(1);
			final value = match.group(2);
			if (name == null || value == null) continue;
			if (name.toLowerCase() == 'expires') continue;
			_cookies[name] = Cookie(name, value);
		}
	}

	Future<void> _persistCookies() async {
		final prefs = await SharedPreferences.getInstance();
		await prefs.setStringList(
			_cookiePrefsKey,
			_cookies.values.map((cookie) => '${cookie.name}=${cookie.value}').toList(),
		);
	}

	@override
	void close() {
		_inner.close();
		super.close();
	}
}

http.Client createHttpClient() => _CookiePersistingClient();
