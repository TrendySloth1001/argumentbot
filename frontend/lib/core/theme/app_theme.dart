import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF2979FF), // Electric Blue
      secondary: Color(0xFF00E5FF), // Cyan Accent
      surface: Color(0xFF121212),
      background: Colors.black,
      onPrimary: Colors.white,
      onSurface: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      hintStyle: const TextStyle(color: Color(0xFF757575)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2979FF), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2979FF),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        letterSpacing: -1.0,
      ),
      bodyLarge: TextStyle(fontSize: 16, color: Color(0xFFE0E0E0)),
    ),
  );
}
