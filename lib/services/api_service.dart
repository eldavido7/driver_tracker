import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth_service.dart';

class ApiService {
  static final String _baseUrl = dotenv.env['API_URL'] ?? '';

  static Future<dynamic> get(String path, {bool useAuth = false}) async {
    return _makeRequest(
      path,
      useAuth: useAuth,
      request: (uri, headers) => http.get(uri, headers: headers),
    );
  }

  static Future<dynamic> post(
    String path,
    Map<String, dynamic> body, {
    bool useAuth = false,
  }) async {
    return _makeRequest(
      path,
      useAuth: useAuth,
      request: (uri, headers) =>
          http.post(uri, headers: headers, body: jsonEncode(body)),
    );
  }

  static Future<dynamic> patch(
    String path,
    Map<String, dynamic> body, {
    bool useAuth = false,
  }) async {
    return _makeRequest(
      path,
      useAuth: useAuth,
      request: (uri, headers) =>
          http.patch(uri, headers: headers, body: jsonEncode(body)),
    );
  }

  static Future<dynamic> delete(String path, {bool useAuth = false}) async {
    return _makeRequest(
      path,
      useAuth: useAuth,
      request: (uri, headers) => http.delete(uri, headers: headers),
    );
  }

  static Future<dynamic> _makeRequest(
    String path, {
    required bool useAuth,
    required Future<http.Response> Function(Uri, Map<String, String>) request,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    var token = useAuth ? await AuthService.getToken() : null;
    var headers = {
      'Content-Type': 'application/json',
      if (useAuth && token != null) 'Authorization': 'Bearer $token',
    };

    debugPrint('Request: $uri, Headers: $headers');
    var res = await request(uri, headers);
    debugPrint(
      'Response: Status ${res.statusCode}, Body: ${res.body.length > 500 ? res.body.substring(0, 500) : res.body}',
    );

    if (res.statusCode == 401 && useAuth) {
      debugPrint('ApiService: 401 received, attempting to refresh token...');
      final refreshed = await AuthService.refreshToken();
      if (refreshed) {
        token = await AuthService.getToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
          res = await request(uri, headers);
          debugPrint(
            'Retry Response: Status ${res.statusCode}, Body: ${res.body.length > 500 ? res.body.substring(0, 500) : res.body}',
          );
        } else {
          throw Exception('Failed to retrieve new token after refresh');
        }
      } else {
        debugPrint('ApiService: Token refresh failed, logging out...');
        await AuthService.logout();
        throw Exception('API Error 401: Token refresh failed');
      }
    }

    return _handleResponse(res);
  }

  static dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      try {
        return jsonDecode(res.body);
      } catch (e) {
        throw FormatException(
          'Invalid JSON response: ${res.body.length > 500 ? res.body.substring(0, 500) : res.body}',
        );
      }
    } else {
      final message = res.body.startsWith('<!DOCTYPE html>')
          ? 'HTML response received, likely incorrect URL or server error'
          : jsonDecode(res.body)['error'] ?? 'Unknown error';
      throw Exception('API Error ${res.statusCode}: $message');
    }
  }
}
