import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:eco_gestion/config/routes.dart';
import 'package:eco_gestion/config/theme_provider.dart';
import 'package:eco_gestion/firebase_options.dart';
import 'package:eco_gestion/services/mqtt_service.dart';
import 'package:eco_gestion/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialiser les services
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  final mqttService = MqttService();
  mqttService.connect(); // Connexion asynchrone au broker MQTT
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'EcoGestion',
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          initialRoute: AppRoutes.splash,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}

// Vous pouvez conserver vos classes SplashScreenWidget et ErrorScreen ici
// ou les déplacer dans des fichiers séparés pour une meilleure organisation
