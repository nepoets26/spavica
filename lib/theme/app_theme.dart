import 'package:flutter/material.dart';

class AppTheme {
  static const primaryColor = Color(0xFF6750A4);
  static const secondaryColor = Color(0xFF625B71); 
  static const backgroundColor = Color(0xFFFFDAE0);
  static const surfaceColor = Color(0xFFFFECF0);
  static const errorColor = Color(0xFFB3261E);

  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      background: backgroundColor,
      surface: surfaceColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
    ),
  );
}
