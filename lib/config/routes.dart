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
import 'package:eco_gestion/screens/smart_meter/meter_history_screen.dart';
import 'package:eco_gestion/screens/prepaid/owner_prepaid_screen.dart';
import 'package:eco_gestion/screens/prepaid/tenant_prepaid_screen.dart';

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
  static const String meterHistory = '/meter-history';
  static const String ownerPrepaid = '/owner-prepaid';
  static const String tenantPrepaid = '/tenant-prepaid';

  // Map des routes
  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    login: (context) => const LoginScreen(),
    authCheck: (context) => const AuthCheck(),
    ownerDashboard: (context) => const OwnerDashboard(),
    tenantDashboard: (context) => const TenantDashboard(),
    profile: (context) => const ProfileScreen(),
    settings: (context) => const SettingsScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    register: (context) => const RegisterScreen(),
    changePassword: (context) => const ChangePasswordScreen(),
    ownerPrepaid: (context) => const OwnerPrepaidScreen(),
    tenantPrepaid: (context) => const TenantPrepaidScreen(),
  };

  // Ajouter cette méthode dans la classe AppRoutes
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    if (settings.name == smartMeterDetail) {
      final args = settings.arguments as Map<String, dynamic>?;
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

    if (settings.name == meterHistory) {
      final args = settings.arguments as Map<String, dynamic>?;
      if (args == null || args['meterId'] == null) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('Erreur: ID du compteur manquant')),
          ),
        );
      }
      return MaterialPageRoute(
        builder: (context) => MeterHistoryScreen(
          meterId: args['meterId'] as String,
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
