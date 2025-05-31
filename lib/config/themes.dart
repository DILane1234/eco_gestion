import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs principales
  static const Color primaryColor = Color(
    0xFF4CAF50,
  ); // Vert pour l'aspect écologique
  static const Color secondaryColor = Color(
    0xFF2196F3,
  ); // Bleu pour l'aspect technologique
  static const Color accentColor = Color(0xFFFFC107); // Jaune pour les alertes

  // Couleurs d'état
  static const Color normalStateColor = Color(
    0xFF4CAF50,
  ); // Vert pour état normal
  static const Color warningStateColor = Color(
    0xFFFFC107,
  ); // Jaune pour avertissement
  static const Color errorStateColor = Color(0xFFF44336); // Rouge pour erreur
  static const Color offlineStateColor = Color(
    0xFF9E9E9E,
  ); // Gris pour hors-ligne

  // Couleurs de fond
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;

  // Couleurs de texte
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color textLightColor = Colors.white;

  // Thème clair
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: backgroundColor, // Remplacement ici
      error: errorStateColor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: textLightColor,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: textLightColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        color: textPrimaryColor,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.bold,
      ),
      displayMedium: TextStyle(
        color: textPrimaryColor,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.bold,
      ),
      displaySmall: TextStyle(
        color: textPrimaryColor,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: textPrimaryColor,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
      ),
      titleLarge: TextStyle(
        color: textPrimaryColor,
        fontFamily: 'Poppins',
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(color: textPrimaryColor, fontFamily: 'Poppins'),
      bodyMedium: TextStyle(color: textSecondaryColor, fontFamily: 'Poppins'),
    ),
  );
}
