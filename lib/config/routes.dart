import 'package:eco_gestion/screens/auth/forgot_password_screen.dart';
import 'package:eco_gestion/screens/auth/register_screen.dart';
import 'package:eco_gestion/screens/dashboard/owner_dashboard.dart';
import 'package:eco_gestion/screens/dashboard/tenant_dashboard.dart';
import 'package:eco_gestion/screens/profile/profile_screen.dart';
import 'package:eco_gestion/screens/settings/settings_screen.dart';
import 'package:eco_gestion/screens/smart_meter/smart_meter_detail.dart';
import 'package:eco_gestion/screens/auth/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:eco_gestion/screens/auth/splash_screen.dart';
import 'package:eco_gestion/screens/auth/login_screen.dart';
import 'package:eco_gestion/screens/auth/auth_check.dart'; 

class AppRoutes {
  // Définition des constantes de routes
  static const String splash = '/splash';
  static const String login = '/login';
  static const String authCheck = '/auth-check';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String smartMeterDetail = '/smart-meter-detail';
  static const String changePassword = '/change-password';
  static const String ownerDashboard = '/owner-dashboard';
  static const String tenantDashboard = '/tenant-dashboard';
  static const String forgotPassword = '/forgot-password';
  static const String register = '/register';

  // Map des routes
  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    authCheck: (context) => const AuthCheck(),
    // Ajoutez vos autres routes ici
    ownerDashboard: (context) => const OwnerDashboard(),
    tenantDashboard: (context) => const TenantDashboard(),
    profile: (context) => const ProfileScreen(),
    settings: (context) => const SettingsScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    register: (context) => const RegisterScreen(),
    // Supprimer cette ligne
    // smartMeterDetail: (context) =>
    //     const SmartMeterDetail(meterId: 'compteur1', isOwner: true),
    changePassword: (context) => const ChangePasswordScreen(),
};

  // Ajouter cette méthode dans la classe AppRoutes
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == smartMeterDetail) {
      // Récupérer les arguments
      final args = settings.arguments as Map<String, dynamic>?;
      
      // Vérifier si l'ID du compteur est fourni
      if (args == null || args['meterId'] == null) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('Erreur: ID du compteur manquant')),
          ),
        );
      }
      
      return MaterialPageRoute(
        builder: (context) => SmartMeterDetail(
          meterId: args['meterId'] as String,
          isOwner: args['isOwner'] as bool,
        ),
      );
    }
    

    
    
    return MaterialPageRoute(
      builder: (_) => const Scaffold(
        body: Center(child: Text('Route non trouvée')),
      ),
    );
  }
}
