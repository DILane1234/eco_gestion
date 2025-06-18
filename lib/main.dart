import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:eco_gestion/config/theme_provider.dart';
import 'package:eco_gestion/config/routes.dart';
import 'package:eco_gestion/screens/auth/auth_check.dart';
import 'package:eco_gestion/screens/auth/login_screen.dart';
import 'package:eco_gestion/screens/auth/register_screen.dart';
import 'package:eco_gestion/screens/dashboard/owner_dashboard.dart';
import 'package:eco_gestion/screens/dashboard/tenant_dashboard.dart';
import 'package:eco_gestion/screens/settings/settings_screen.dart';
import 'package:eco_gestion/screens/auth/forgot_password_screen.dart';
import 'package:eco_gestion/screens/profile/profile_screen.dart';
import 'firebase_options.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configure Firebase Database
  final database = FirebaseDatabase.instance;
  database.setPersistenceEnabled(true);
  database.setPersistenceCacheSizeBytes(10000000);

  // Configurer la base de données pour une meilleure connexion
  database.ref().keepSynced(true);

  // Définir l'URL de la base de données si nécessaire
  // database.databaseURL = 'https://votre-projet.firebaseio.com';

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'EcoGestion',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.lightTheme,
            darkTheme: themeProvider.darkTheme,
            themeMode:
                themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: AppRoutes.authCheck,
            routes: {
              AppRoutes.authCheck: (context) => const AuthCheck(),
              AppRoutes.login: (context) => const LoginScreen(),
              AppRoutes.register: (context) => const RegisterScreen(),
              AppRoutes.ownerDashboard: (context) => const OwnerDashboard(),
              AppRoutes.tenantDashboard: (context) => const TenantDashboard(),
              AppRoutes.settings: (context) => const SettingsScreen(),
              AppRoutes.forgotPassword: (context) =>
                  const ForgotPasswordScreen(),
              AppRoutes.profile: (context) => const ProfileScreen(),
            },
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
