import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_service.dart';
import 'login_screen.dart';
import '../dashboard/owner_dashboard.dart';
import '../dashboard/tenant_dashboard.dart';
import 'package:eco_gestion/config/routes.dart';

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          print(
              'Aucun utilisateur authentifié, redirection vers la page de connexion');
          return const LoginScreen();
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: _firebaseService.checkAuthState(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (authSnapshot.hasError) {
              print(
                  'Erreur lors de la vérification de l\'authentification: ${authSnapshot.error}');
              return const LoginScreen();
            }

            final authData = authSnapshot.data;
            if (authData == null || !authData['isAuthenticated']) {
              print(
                  'Données d\'authentification invalides ou utilisateur non authentifié');
              return const LoginScreen();
            }

            final userType = authData['userType'] as String?;
            if (userType == null ||
                (userType != 'owner' && userType != 'tenant')) {
              print('Type d\'utilisateur invalide: $userType');
              return const LoginScreen();
            }

            print('Navigation vers le dashboard: $userType');
            return userType == 'owner'
                ? const OwnerDashboard()
                : const TenantDashboard();
          },
        );
      },
    );
  }
}
