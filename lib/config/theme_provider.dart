import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  // Charger le thème depuis les préférences
  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  // Basculer entre les thèmes
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    
    // Sauvegarder la préférence
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    
    notifyListeners();
  }

  // Thème clair
  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.green,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.white,
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  // Thème sombre
  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.green,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.grey.shade900,
      cardTheme: CardTheme(
        color: Colors.grey.shade800,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.grey.shade900,
        selectedItemColor: Colors.green,
        unselectedItemColor: Colors.grey,
      ),
    );
  }

  // Ajouter ce getter après les getters lightTheme et darkTheme
  
  // Thème actuel basé sur le mode
  ThemeData get currentTheme {
    return _isDarkMode ? darkTheme : lightTheme;
  }
}