import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/debate.dart';

class DebateService {
  final _storage = const FlutterSecureStorage();

  String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  Future<Debate> startDebate(String topic) async {
    final token = await _storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/debate/start'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'topic': topic}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Debate.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to start debate: ${response.statusCode}');
    }
  }

  Future<Debate> nextTurn(String debateId) async {
    final token = await _storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/debate/$debateId/next'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Debate.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to process next turn: ${response.statusCode}');
    }
  }

  Future<Debate> getDebate(String debateId) async {
    final token = await _storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/debate/$debateId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return Debate.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load debate: ${response.statusCode}');
    }
  }

  Future<List<Debate>> getDebates() async {
    final token = await _storage.read(key: 'jwt_token');
    final response = await http.get(
      Uri.parse('$baseUrl/debate'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Debate.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load debates: ${response.statusCode}');
    }
  }
}
