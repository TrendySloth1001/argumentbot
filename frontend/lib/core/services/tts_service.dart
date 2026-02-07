import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import '../../features/auth/data/services/auth_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';
import '../data/voice_settings.dart';

class TtsService {
  final AuthService _authService = AuthService();

  /// Synthesize text to speech and return audio bytes
  Future<Uint8List> synthesize(String text, {String? voice}) async {
    // 1. Check cache first
    final cacheEnabled = await VoiceSettings.getAudioCacheEnabled();
    File? cacheFile;

    if (cacheEnabled) {
      try {
        cacheFile = await _getCacheFile(text, voice);
        if (await cacheFile.exists()) {
          print('TTS: Cache hit for "${text.substring(0, 10)}..."');
          return await cacheFile.readAsBytes();
        }
      } catch (e) {
        print('TTS: Cache check failed: $e');
      }
    }

    // 2. Fetch from API
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
      final bytes = response.bodyBytes;
      // 3. Save to cache
      if (cacheEnabled && cacheFile != null) {
        try {
          await cacheFile.writeAsBytes(bytes);
          print('TTS: Cached audio to ${cacheFile.path}');
        } catch (e) {
          print('TTS: Cache write failed: $e');
        }
      }
      return bytes;
    } else {
      throw Exception('TTS synthesis failed: ${response.statusCode}');
    }
  }

  /// Generate cache file path based on MD5 hash of content
  Future<File> _getCacheFile(String text, String? voice) async {
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/tts_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    // Hash key: text + voice
    final key = '${text}_${voice ?? "default"}';
    final hash = md5.convert(utf8.encode(key)).toString();

    return File('${cacheDir.path}/$hash.wav');
  }

  /// Clear all cached audio files
  Future<void> clearAudioCache() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/tts_cache');
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('TTS: Cache cleared');
      }
    } catch (e) {
      print('TTS: Failed to clear cache: $e');
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/tts_cache');
      if (await cacheDir.exists()) {
        int size = 0;
        await for (var file in cacheDir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (file is File) {
            size += await file.length();
          }
        }
        return size;
      }
      return 0;
    } catch (e) {
      return 0;
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
