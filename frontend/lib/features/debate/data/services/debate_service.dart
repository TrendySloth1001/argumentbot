import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/data/settings_manager.dart';
import '../models/debate.dart';

class DebateService {
  final _storage = const FlutterSecureStorage();

  String get baseUrl => ApiConfig.baseUrl;

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

  Stream<Map<String, dynamic>> streamTurn(String debateId) async* {
    final mode = await SettingsManager.getScoringMode();
    final token = await _storage.read(key: 'jwt_token');

    final client = http.Client();
    try {
      final request = http.Request(
        'GET',
        Uri.parse('$baseUrl/debate/$debateId/stream?scoringMode=$mode'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'text/event-stream';

      final response = await client.send(request);

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        // SSE format is "data: {...}\n\n"
        // We might get multiple lines or partial lines
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            if (jsonStr.trim().isNotEmpty) {
              try {
                yield jsonDecode(jsonStr);
              } catch (e) {
                // ignore parse errors
              }
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }

  Future<Debate> nextTurn(String debateId) async {
    final mode = await SettingsManager.getScoringMode();
    final token = await _storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/debate/$debateId/next'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'scoringMode': mode}),
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
