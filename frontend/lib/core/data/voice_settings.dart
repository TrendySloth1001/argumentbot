import 'package:shared_preferences/shared_preferences.dart';

/// Voice model for TTS selection
class VoiceModel {
  final String id;
  final String name;
  final String gender;
  final String accent;
  final String quality;
  final String description;

  const VoiceModel({
    required this.id,
    required this.name,
    required this.gender,
    required this.accent,
    required this.quality,
    required this.description,
  });

  factory VoiceModel.fromJson(Map<String, dynamic> json) {
    return VoiceModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'] ?? 'unknown',
      accent: json['accent'] ?? 'unknown',
      quality: json['quality'] ?? 'medium',
      description: json['description'] ?? '',
    );
  }

  String get displayName => '$name ($accent ${gender == "female" ? "♀" : "♂"})';
}

/// Manages voice preferences for proponent and opponent
class VoiceSettings {
  static const String _proponentVoiceKey = 'proponent_voice';
  static const String _opponentVoiceKey = 'opponent_voice';
  static const String _defaultVoice = 'en_US-amy-medium';

  /// Get proponent voice ID
  static Future<String> getProponentVoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_proponentVoiceKey) ?? _defaultVoice;
  }

  /// Set proponent voice ID
  static Future<void> setProponentVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_proponentVoiceKey, voiceId);
  }

  /// Get opponent voice ID
  static Future<String> getOpponentVoice() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to a different voice for opponent
    return prefs.getString(_opponentVoiceKey) ?? 'en_US-ryan-high';
  }

  /// Set opponent voice ID
  static Future<void> setOpponentVoice(String voiceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_opponentVoiceKey, voiceId);
  }

  /// Get audio caching preference (default: true)
  static Future<bool> getAudioCacheEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('audio_cache_enabled') ?? true;
  }

  /// Set audio caching preference
  static Future<bool> setAudioCacheEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool('audio_cache_enabled', enabled);
  }
}
