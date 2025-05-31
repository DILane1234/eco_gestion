import 'package:flutter/material.dart';
import 'package:eco_gestion/services/firebase_service.dart';
import 'package:eco_gestion/config/routes.dart';

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    print('AuthCheck: initState appelé');
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    print('AuthCheck: Début de la vérification d\'authentification');
    
    // Attendre un peu pour permettre à Firebase de s'initialiser
    await Future.delayed(const Duration(seconds: 1));
    print('AuthCheck: Délai d\'initialisation terminé');
    
    print('AuthCheck: État utilisateur: ${_firebaseService.currentUser != null ? 'Connecté' : 'Non connecté'}');
    
    if (_firebaseService.currentUser != null) {
      // L'utilisateur est connecté, vérifier son type
      print('AuthCheck: Récupération du type d\'utilisateur...');
      String? userType = await _firebaseService.getUserType();
      print('AuthCheck: Type d\'utilisateur récupéré: $userType');
      
      if (mounted) {
        try {
          print('AuthCheck: Tentative de navigation basée sur le type d\'utilisateur: $userType');
          if (userType == 'owner') {
            print('AuthCheck: Navigation vers le tableau de bord propriétaire');
            Navigator.pushReplacementNamed(context, AppRoutes.ownerDashboard);
          } else if (userType == 'tenant') {
            print('AuthCheck: Navigation vers le tableau de bord locataire');
            Navigator.pushReplacementNamed(context, AppRoutes.tenantDashboard);
          } else {
            // Type d'utilisateur non défini, rediriger vers la connexion
            print('AuthCheck: Type d\'utilisateur non reconnu, redirection vers login');
            Navigator.pushReplacementNamed(context, AppRoutes.login);
          }
        } catch (e) {
          // En cas d'erreur de navigation, rediriger vers la connexion
          print('AuthCheck: Erreur de navigation: $e');
          print('AuthCheck: Redirection vers login suite à une erreur');
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
      } else {
        print('AuthCheck: Widget non monté, navigation annulée');
      }
    } else {
      // L'utilisateur n'est pas connecté, rediriger vers la connexion
      print('AuthCheck: Utilisateur non connecté');
      if (mounted) {
        print('AuthCheck: Redirection vers login');
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      } else {
        print('AuthCheck: Widget non monté, navigation annulée');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('AuthCheck: Méthode build appelée');
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}