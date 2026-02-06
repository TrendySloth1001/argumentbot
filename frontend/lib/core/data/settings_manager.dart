import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const String _keyScoringMode = 'scoring_mode';

  static Future<void> setScoringMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyScoringMode, mode);
  }

  static Future<String> getScoringMode() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 2),
        onTimeout: () => throw Exception('Timeout'),
      );
      return prefs.getString(_keyScoringMode) ?? 'AI';
    } catch (e) {
      return 'AI'; // Default fallback on error/timeout
    }
  }
}
