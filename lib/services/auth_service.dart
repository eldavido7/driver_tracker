import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env.dart';
import '../models/user.dart';

class AuthService {
  static const _storage = FlutterSecureStorage();

  static Future<UserModel> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('${Env.apiUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        throw Exception('Invalid server response');
      }

      if (res.statusCode == 200 &&
          data != null &&
          data['user'] != null &&
          data['token'] != null &&
          data['refreshToken'] != null) {
        // Store both tokens
        await _storage.write(key: 'token', value: data['token']);
        await _storage.write(key: 'refreshToken', value: data['refreshToken']);

        return UserModel.fromJson(data['user']);
      } else {
        final errorMessage = data?['error'] ?? 'Login failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  static Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('${Env.apiUrl}/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      Map<String, dynamic>? data;
      try {
        data = jsonDecode(res.body);
      } catch (e) {
        throw Exception(
          'Invalid server response. Status: ${res.statusCode}, Body: ${res.body}',
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201) {
        // Check if we have the required fields
        if (data != null &&
            data['user'] != null &&
            data['token'] != null &&
            data['refreshToken'] != null) {
          await _storage.write(key: 'token', value: data['token']);
          await _storage.write(
            key: 'refreshToken',
            value: data['refreshToken'],
          );
          return UserModel.fromJson(data['user']);
        } else {
          // Handle case where registration was successful but response structure is different
          if (data != null && data['user'] != null && data['token'] != null) {
            await _storage.write(key: 'token', value: data['token']);
            // If no refreshToken, just store the regular token
            await _storage.write(key: 'refreshToken', value: data['token']);
            return UserModel.fromJson(data['user']);
          } else {
            throw Exception(
              'Registration successful but incomplete response data. Response: ${res.body}',
            );
          }
        }
      } else {
        final errorMessage =
            data?['error'] ?? data?['message'] ?? 'Registration failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      // Don't wrap the exception if it's already our custom exception
      if (e.toString().contains(
            'Registration successful but incomplete response data',
          ) ||
          e.toString().contains('Invalid server response')) {
        rethrow;
      }
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refreshToken');
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'refreshToken');
  }

  static Future<bool> refreshToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final res = await http.post(
        Uri.parse('${Env.apiUrl}/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['token'] != null && data['refreshToken'] != null) {
          // Store new tokens
          await _storage.write(key: 'token', value: data['token']);
          await _storage.write(
            key: 'refreshToken',
            value: data['refreshToken'],
          );
          return true;
        }
      }
    } catch (e) {
      throw Exception('Token refresh failed: $e');
    }

    return false;
  }

  static Future<UserModel?> getUserFromToken() async {
    String? token = await getToken();
    if (token == null) return null;

    try {
      final res = await http.get(
        Uri.parse('${Env.apiUrl}/api/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return UserModel.fromJson(data['user']);
      } else if (res.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await refreshToken();
        if (refreshed) {
          // Try again with new token
          token = await getToken();
          if (token != null) {
            final newRes = await http.get(
              Uri.parse('${Env.apiUrl}/api/auth/me'),
              headers: {'Authorization': 'Bearer $token'},
            );

            if (newRes.statusCode == 200) {
              final data = jsonDecode(newRes.body);
              return UserModel.fromJson(data['user']);
            }
          }
        }

        // Refresh failed, clear tokens
        await logout();
        return null;
      }
    } catch (e) {
      throw Exception('Get user from token failed: $e');
    }

    return null;
  }
}
