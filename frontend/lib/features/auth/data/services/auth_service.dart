import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  static String get baseUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  Future<bool> register(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        // Parse error message if available
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Registration failed');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Login failed');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}
