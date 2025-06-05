import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:eco_gestion/config/routes.dart';
import 'package:eco_gestion/config/theme_provider.dart';
import 'package:eco_gestion/firebase_options.dart';
import 'package:eco_gestion/services/mqtt_service.dart';
import 'package:eco_gestion/services/notification_service.dart';

// Au début du fichier, après les imports
import 'package:flutter/foundation.dart' show kDebugMode;

// Fonction utilitaire pour les logs
void logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

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
        // Dans la méthode build du widget App
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'EcoGestion',
          theme: ThemeData(
            primarySwatch: Colors.green,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),
          routes: AppRoutes.routes,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          initialRoute: AppRoutes.splash,
        );
      },
    );
  }
}
