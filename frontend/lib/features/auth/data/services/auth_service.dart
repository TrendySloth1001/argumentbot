import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();

  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  static String get baseUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  Future<User?> checkAuth() async {
    if (kDebugMode) {
      print('AuthService: checkAuth started');
    }
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (kDebugMode) {
        print(
        'AuthService: token read from storage: ${token != null ? "FOUND" : "NULL"}',
      );
      }

      if (token == null) return null;

      final url = Uri.parse('$baseUrl/auth/verify');
      if (kDebugMode) {
        print('AuthService: verifying with $url');
      }

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 5)); // Add 5s timeout

      if (kDebugMode) {
        print('AuthService: response status ${response.statusCode}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User(
          id: data['userId'],
          email: data['email'],
          username: data['username'] ?? 'User',
          createdAt: '',
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('AuthService: checkAuth error: $e');
      }
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<User> register(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          await _storage.write(key: 'jwt_token', value: data['token']);
        }
        return User.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<User> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['token'] != null) {
          await _storage.write(key: 'jwt_token', value: data['token']);
        }
        return User.fromJson(data['user']);
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}
