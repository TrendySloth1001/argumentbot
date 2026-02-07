import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../../features/auth/data/services/auth_service.dart';

class TtsService {
  final AuthService _authService = AuthService();

  /// Synthesize text to speech and return audio bytes
  Future<Uint8List> synthesize(String text, {String? voice}) async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/tts/synthesize'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'text': text, if (voice != null) 'voice': voice}),
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('TTS synthesis failed: ${response.statusCode}');
    }
  }

  /// Get list of available voices
  Future<List<Map<String, dynamic>>> getVoices() async {
    final token = await _authService.getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/tts/voices'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);

        // Handle both List (direct from backend) and Map (wrapped) formats
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('voices')) {
          return List<Map<String, dynamic>>.from(data['voices']);
        }

        return [];
      } else {
        throw Exception('Failed to get voices: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching voices: $e');
      rethrow;
    }
  }

  /// Check if TTS service is healthy
  Future<bool> isHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/tts/health'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
