import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/data/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/debate.dart';

class DebateService {
  final _storage = const FlutterSecureStorage();

  String get baseUrl => ApiConfig.baseUrl;

  Future<Debate> startDebate(
    String topic, {
    String mode = 'AI_VS_AI',
    String userRole = 'SPECTATOR',
  }) async {
    final token = await _storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/debate/start'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'topic': topic, 'mode': mode, 'userRole': userRole}),
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

  Future<DebateTurn> submitUserTurn(String debateId, String content) async {
    final token = await _storage.read(key: 'jwt_token');
    final response = await http.post(
      Uri.parse('$baseUrl/debate/$debateId/user-turn'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return DebateTurn.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to submit turn: ${response.statusCode}');
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
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/debate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final debates = data.map((json) => Debate.fromJson(json)).toList();
        await _cacheDebates(debates);
        return debates;
      } else {
        throw Exception('Failed to load debates: ${response.statusCode}');
      }
    } catch (e) {
      print('Network error, trying cache: $e');
      final cached = await _loadCachedDebates();
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<void> _cacheDebates(List<Debate> debates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = debates.map((d) => d.toJson()).toList();
      await prefs.setString('cached_debates', jsonEncode(jsonList));
    } catch (e) {
      print('Failed to cache debates: $e');
    }
  }

  Future<List<Debate>> _loadCachedDebates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_debates');
      if (jsonString != null) {
        final List<dynamic> data = jsonDecode(jsonString);
        return data.map((json) => Debate.fromJson(json)).toList();
      }
    } catch (e) {
      print('Failed to load cached debates: $e');
    }
    return [];
  }
}
