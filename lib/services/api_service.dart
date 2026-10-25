import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message, {this.status, this.code, this.errors});
  final String message;
  final int? status;
  final String? code;
  final Map<String, dynamic>? errors;
  @override
  String toString() => message;
}

class ApiService {
  ApiService._();
  // The shared integration backend supplies this URL; no server is bundled.
  static String baseUrl = const String.fromEnvironment('API_BASE_URL');
  static const _requestTimeout = Duration(seconds: 20);
  // Memory only: no unencrypted token persistence. Demo login never issues a token.
  static String? _token;
  static void setToken(String? token) => _token = token;
  static Future<dynamic> get(String endpoint) => request('GET', endpoint);
  static Future<dynamic> post(
    String endpoint, {
    required Map<String, dynamic> body,
  }) => request('POST', endpoint, body: body);
  static Future<dynamic> patch(
    String endpoint, {
    required Map<String, dynamic> body,
  }) => request('PATCH', endpoint, body: body);
  static Future<dynamic> delete(String endpoint) => request('DELETE', endpoint);
  static Future<dynamic> request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    if (!endpoint.startsWith('/') ||
        endpoint.contains('://') ||
        endpoint.contains('..')) {
      throw const ApiException('Invalid API endpoint.');
    }
    final apiUri = Uri.tryParse(baseUrl);
    if (apiUri == null ||
        !apiUri.hasAuthority ||
        !const ['http', 'https'].contains(apiUri.scheme)) {
      throw const ApiException(
        'The shared service is not configured yet. Please use a demo account.',
      );
    }
    final client = http.Client();
    try {
      final request = http.Request(
        method,
        Uri.parse('${baseUrl.replaceFirst(RegExp(r"/$"), "")}$endpoint'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(_requestTimeout);
      dynamic payload;
      try {
        payload = response.body.isEmpty ? null : jsonDecode(response.body);
      } on FormatException {
        throw ApiException(
          'The server returned an unreadable response.',
          status: response.statusCode,
        );
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return payload;
      }
      if (response.statusCode == 401) _token = null;
      final map = payload is Map<String, dynamic>
          ? payload
          : <String, dynamic>{};
      throw ApiException(
        map['message'] as String? ?? 'Unable to complete the request.',
        status: response.statusCode,
        code: map['code'] as String?,
        errors: map['errors'] as Map<String, dynamic>?,
      );
    } on TimeoutException {
      throw const ApiException('The server took too long. Please try again.');
    } on http.ClientException {
      throw const ApiException(
        'Cannot connect to Lumear. Check your internet connection and try again.',
      );
    } finally {
      client.close();
    }
  }
}
