import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class VercelApiException implements Exception {
  const VercelApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
}

/// Shared transport for authenticated calls to the Vercel API.
/// The bearer token stays in memory and is cleared on logout.
class VercelApiClient {
  VercelApiClient({http.Client? client}) : _client = client ?? http.Client();

  static final VercelApiClient instance = VercelApiClient();

  final http.Client _client;
  String? _accessToken;
  String? _refreshToken;
  Future<bool>? _refreshing;

  bool get hasSession => _accessToken != null;
  void setSession({required String accessToken, String? refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }
  void clearSession() {
    _accessToken = null;
    _refreshToken = null;
  }

  Uri _uri(String path) {
    const baseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://resultsapp-gray.vercel.app',
    );
    if (baseUrl.isEmpty) {
      throw const VercelApiException('Backend URL is not configured.');
    }
    return Uri.parse(baseUrl).resolve(path);
  }

  Future<Map<String, dynamic>> get(String path) async {
    return _request('GET', path);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, Object?> body,
      {bool authenticated = true}) async {
    return _request('POST', path, body: body, authenticated: authenticated);
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, Object?> body) async {
    return _request('PATCH', path, body: body);
  }

  Future<Map<String, dynamic>> _request(String method, String path,
      {Map<String, Object?>? body, bool authenticated = true}) async {
    var response = await _send(method, path, body: body, authenticated: authenticated);
    if (authenticated && response.statusCode == 401 && _refreshToken != null) {
      if (!await _refreshSession()) {
        clearSession();
        return _decode(response);
      }
      response = await _send(method, path, body: body, authenticated: true);
    }
    return _decode(response);
  }

  Future<http.Response> _send(String method, String path,
      {Map<String, Object?>? body, required bool authenticated}) {
    final uri = _uri(path);
    final headers = _headers(authenticated: authenticated);
    final encodedBody = body == null ? null : jsonEncode(body);
    switch (method) {
      case 'GET': return _client.get(uri, headers: headers);
      case 'POST': return _client.post(uri, headers: headers, body: encodedBody);
      case 'PATCH': return _client.patch(uri, headers: headers, body: encodedBody);
      default: throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
    }
  }

  Future<bool> _refreshSession() async {
    final pending = _refreshing;
    if (pending != null) return pending;
    final refresh = _refreshSessionOnce();
    _refreshing = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshing, refresh)) _refreshing = null;
    }
  }

  Future<bool> _refreshSessionOnce() async {
    final token = _refreshToken;
    if (token == null) return false;
    try {
      final response = await _client.post(
        _uri('/api/v1/auth/refresh'),
        headers: _headers(authenticated: false),
        body: jsonEncode({'refreshToken': token}),
      );
      final data = _decode(response);
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];
      if (accessToken is! String || refreshToken is! String) return false;
      setSession(accessToken: accessToken, refreshToken: refreshToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> putBytes(String url, List<int> bytes, {required String contentType}) async {
    final response = await _client.put(
      Uri.parse(url),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw VercelApiException('Secure file upload failed (${response.statusCode}).', statusCode: response.statusCode);
    }
  }

  Future<void> putFile(String url, String path, {required String contentType, required int contentLength, List<int>? bytes}) async {
    if (kIsWeb || bytes != null) {
      if (bytes != null) {
        return putBytes(url, bytes, contentType: contentType);
      }
      throw const VercelApiException('File bytes are required for upload on the web.');
    }
    final request = http.StreamedRequest('PUT', Uri.parse(url));
    request.headers['Content-Type'] = contentType;
    request.contentLength = contentLength;
    final responseFuture = _client.send(request);
    try {
      await request.sink.addStream(File(path).openRead());
      await request.sink.close();
      final response = await responseFuture;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw VercelApiException('Secure file upload failed (${response.statusCode}).', statusCode: response.statusCode);
      }
      await response.stream.drain<void>();
    } catch (_) {
      request.sink.close();
      rethrow;
    }
  }

  Map<String, String> _headers({bool authenticated = true}) => {
        'Content-Type': 'application/json',
        if (authenticated && _accessToken != null)
          'Authorization': 'Bearer $_accessToken',
      };

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const VercelApiException('The server returned an invalid response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final message = error is Map<String, dynamic> && error['message'] is String
          ? error['message'] as String
          : 'Unable to complete the request.';
      throw VercelApiException(message, statusCode: response.statusCode);
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is List<dynamic>) return {'items': data};
    throw const VercelApiException('The server returned an invalid response.');
  }
}
