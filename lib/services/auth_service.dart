import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

enum UserRole {
  owner,
  tenant,
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream pour suivre les changements d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Inscription avec email et mot de passe
  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required UserRole role,
  }) async {
    try {
      // Créer l'utilisateur dans Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Créer le profil utilisateur dans Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'role': role.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Mettre à jour le displayName de l'utilisateur
      await userCredential.user!.updateDisplayName(name);

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Connexion avec email et mot de passe
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Récupérer le rôle de l'utilisateur
  Future<UserRole> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();

      if (data != null && data.containsKey('role')) {
        final roleStr = data['role'] as String;
        return roleStr == 'owner' ? UserRole.owner : UserRole.tenant;
      }

      // Par défaut, on considère l'utilisateur comme locataire
      return UserRole.tenant;
    } catch (e) {
      // En cas d'erreur, on considère l'utilisateur comme locataire
      return UserRole.tenant;
    }
  }

  // Réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Vérifier si l'utilisateur est connecté
  bool get isAuthenticated => _auth.currentUser != null;

  // Récupérer les données de l'utilisateur
  Future<Map<String, dynamic>> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data() ?? {};
      }
      return {};
    } catch (e) {
      print('Erreur lors de la récupération des données utilisateur: $e');
      return {};
    }
  }

  // Vérifier les permissions d'accès au compteur
  Future<bool> canAccessMeter(String meterId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userData = await getUserData();
      final role = userData['role'];
      final userMeterId = userData['meterId'];

      // Si l'utilisateur est propriétaire, il a accès à tous les compteurs
      if (role == 'owner') return true;

      // Si l'utilisateur est locataire, il n'a accès qu'à son propre compteur
      if (role == 'tenant' && userMeterId == meterId) return true;

      return false;
    } catch (e) {
      print('Erreur lors de la vérification des permissions: $e');
      return false;
    }
  }

  // Récupérer le type d'utilisateur (propriétaire ou locataire)
  Future<String?> getCurrentUserRole() async {
    final userData = await getUserData();
    return userData['role'];
  }

  // Récupérer l'ID du compteur de l'utilisateur
  Future<String?> getUserMeterId() async {
    final userData = await getUserData();
    return userData['meterId'];
  }

  // Assigner un compteur à un locataire
  Future<void> assignMeterToTenant(String tenantUid, String meterId) async {
    try {
      await _firestore.collection('users').doc(tenantUid).update({
        'meterId': meterId,
      });
    } catch (e) {
      print('Erreur lors de l\'assignation du compteur: $e');
      rethrow;
    }
  }
}
