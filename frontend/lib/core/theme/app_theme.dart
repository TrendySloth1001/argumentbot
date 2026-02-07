import 'package:flutter/material.dart';

/// App-wide theme constants
/// Design: Minimalist black with neon green accents
class AppTheme {
  // Primary colors
  static const Color background = Colors.black;
  static const Color neonGreen = Color(0xFF00FF88);
  static const Color neonPurple = Color(0xFF8E2DE2);

  // Dark theme for MaterialApp
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    primaryColor: neonGreen,
    colorScheme: const ColorScheme.dark(
      primary: neonGreen,
      secondary: neonPurple,
      surface: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: neonGreen),
  );

  // Text colors
  static const Color textPrimary = Colors.white;
  static Color textSecondary = Colors.grey[400]!;
  static Color textMuted = Colors.grey[600]!;

  // Surface colors
  static Color surface = Colors.grey[900]!;
  static Color surfaceLight = Colors.grey[800]!;
  static Color divider = Colors.grey[800]!;

  // Accent color (use neonGreen as primary accent)
  static const Color accent = neonGreen;

  // Status colors
  static const Color active = neonGreen;
  static Color inactive = Colors.grey[600]!;
  static const Color error = Colors.redAccent;
  static const Color success = neonGreen;

  // Text styles
  static const TextStyle headingLarge = TextStyle(
    color: textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle headingMedium = TextStyle(
    color: textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyText = TextStyle(
    color: Colors.white70,
    fontSize: 14,
  );

  static TextStyle labelText = TextStyle(
    color: Colors.grey[500],
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
  );

  // Decorations
  static BoxDecoration cardDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(12),
  );

  static BoxDecoration accentCardDecoration = BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: neonGreen.withAlpha(77)),
  );

  // Gradient divider
  static Widget gradientDivider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey[800]!,
            Colors.grey[800]!,
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
    );
  }

  // Avatar with neon border
  static Widget avatar({
    String? imageUrl,
    String? fallbackText,
    double size = 48,
    double borderWidth = 2,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: neonGreen, width: borderWidth),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: size - borderWidth * 2,
                height: size - borderWidth * 2,
                errorBuilder: (_, __, ___) =>
                    _avatarFallback(fallbackText, size),
              )
            : _avatarFallback(fallbackText, size),
      ),
    );
  }

  static Widget _avatarFallback(String? text, double size) {
    return Container(
      color: background,
      alignment: Alignment.center,
      child: Text(
        (text?.isNotEmpty == true) ? text![0].toUpperCase() : 'U',
        style: TextStyle(
          color: neonGreen,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}


/**
 * 
 * 2. 🗣️ Voice Debates (Podcast Mode)
Turn text debates into audio.

How: Use Text-to-Speech (ElevenLabs or OS default) to give Model A and Model B distinct voices.
Cool Factor: Users can listen to debates like a podcast while driving or working.
3. 🎭 Personality Matchups
Let users pick the "vibe" of the debaters.

Example: "Gen Z Zoomer" vs "Shakespearean Scholar"
Example: "Angry Reddit Mod" vs "Chill Surfer"
Cool Factor: Infinite entertainment value from clashing styles.
 */