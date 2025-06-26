import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_gestion/models/user_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:math';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Obtenir l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream pour suivre l'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Inscription avec email et mot de passe
  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String userType, // 'owner' ou 'tenant'
    String? name, // Ajout du paramètre nom
  }) async {
    try {
      print('Début de l\'inscription...');
      print('Email: $email');
      print('Type d\'utilisateur: $userType');
      print('Nom: ${name ?? "Non fourni"}');

      // Créer l'utilisateur dans Firebase Auth
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Échec de la création du compte');
      }

      print('Compte créé avec succès. UID: ${userCredential.user!.uid}');

      // Stocker les informations dans Firestore
      try {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': email,
          'userType': userType,
          'name': name ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('Données utilisateur enregistrées dans Firestore');
      } catch (e) {
        print('Erreur lors de l\'enregistrement dans Firestore: $e');
        // Si l'enregistrement Firestore échoue, supprimer le compte Auth
        await userCredential.user?.delete();
        throw Exception('Erreur lors de la création du profil utilisateur');
      }

      // Vérifier que tout est bien configuré
      final authState = await checkAuthState();
      if (!authState['hasFirestoreData']) {
        throw Exception('Échec de la vérification des données utilisateur');
      }

      return userCredential;
    } catch (e) {
      print('Erreur lors de l\'inscription: $e');
      rethrow;
    }
  }

  // Connexion avec email et mot de passe
  Future<Map<String, dynamic>> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      print('Tentative de connexion pour: $email');

      // 1. Connexion Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception('Échec de la connexion: Aucun utilisateur retourné');
      }

      print(
          'Connexion Firebase Auth réussie pour: ${userCredential.user!.uid}');

      // 2. Forcer le rafraîchissement du token
      await userCredential.user!.getIdToken(true);
      print('Token rafraîchi avec succès');

      // 3. Vérifier si l'utilisateur existe dans Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        print('Utilisateur non trouvé dans Firestore');
        throw Exception('Utilisateur non trouvé dans la base de données');
      }

      final userData = userDoc.data();
      if (userData == null) {
        print('Données utilisateur manquantes dans Firestore');
        throw Exception('Données utilisateur incomplètes');
      }

      // 4. Vérifier le type d'utilisateur
      final userType = userData['userType'] as String?;
      print('Type d\'utilisateur trouvé: $userType');

      if (userType == null || (userType != 'owner' && userType != 'tenant')) {
        print('Type d\'utilisateur invalide: $userType');
        throw Exception('Type d\'utilisateur invalide');
      }

      // 5. Retourner les données utilisateur dans un format simple
      final userInfo = {
        'uid': userCredential.user!.uid,
        'email': userCredential.user!.email,
        'userType': userType,
        'name': userData['name'] as String? ?? 'Utilisateur',
        'isAuthenticated': true,
        'hasValidToken': true,
        'hasFirestoreData': true,
      };

      print('Connexion réussie pour: ${userInfo['email']}');
      print('Type d\'utilisateur: ${userInfo['userType']}');
      print('Données utilisateur complètes: $userInfo');
      return userInfo;
    } on FirebaseAuthException catch (e) {
      print('Erreur Firebase Auth: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'Aucun utilisateur trouvé avec cet email';
          break;
        case 'wrong-password':
          errorMessage = 'Mot de passe incorrect';
          break;
        case 'invalid-email':
          errorMessage = 'Format d\'email invalide';
          break;
        case 'user-disabled':
          errorMessage = 'Ce compte a été désactivé';
          break;
        case 'too-many-requests':
          errorMessage = 'Trop de tentatives. Veuillez réessayer plus tard';
          break;
        default:
          errorMessage = 'Erreur de connexion: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      print('Erreur de connexion: $e');
      throw Exception('Erreur de connexion. Veuillez réessayer');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    try {
      print('Déconnexion en cours...');

      // 1. Déconnecter de Firebase Auth
      await _auth.signOut();

      // 2. Nettoyer les caches de la base de données
      await FirebaseDatabase.instance.goOffline();

      // 3. Attendre un court instant pour s'assurer que tout est nettoyé
      await Future.delayed(const Duration(milliseconds: 500));

      // 4. Vérifier que la déconnexion a réussi
      if (_auth.currentUser != null) {
        print('La déconnexion n\'a pas réussi, nouvelle tentative...');
        await _auth.signOut();
        // Attendre à nouveau
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 5. Vérification finale
      if (_auth.currentUser != null) {
        throw Exception('Impossible de déconnecter l\'utilisateur');
      }

      print('Déconnexion réussie');
    } catch (e) {
      print('Erreur lors de la déconnexion: $e');
      // Forcer la déconnexion même en cas d'erreur
      await _auth.signOut();
      // Relancer l'erreur pour que l'UI puisse réagir
      rethrow;
    }
  }

  // Récupérer le type d'utilisateur (propriétaire ou locataire)
  Future<String?> getUserType() async {
    try {
      if (currentUser != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUser!.uid).get();

        if (userDoc.exists) {
          return userDoc.get('userType') as String?;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Récupérer le nom de l'utilisateur
  Future<String?> getUserName() async {
    try {
      if (currentUser != null) {
        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(currentUser!.uid).get();

        if (userDoc.exists && userDoc.data() is Map<String, dynamic>) {
          Map<String, dynamic> userData =
              userDoc.data() as Map<String, dynamic>;
          return userData['name'] as String?;
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la récupération du nom: $e');
      }
      return null;
    }
  }

  // Changer le mot de passe
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Vérifier que l'utilisateur est connecté
      final user = currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      // Récupérer l'email de l'utilisateur
      final email = user.email;
      if (email == null) {
        throw Exception('Email de l\'utilisateur non disponible');
      }

      // Réauthentifier l'utilisateur avec son mot de passe actuel
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      try {
        await user.reauthenticateWithCredential(credential);
      } catch (e) {
        if (e is FirebaseAuthException) {
          if (e.code == 'wrong-password') {
            throw Exception('Le mot de passe actuel est incorrect');
          } else if (e.code == 'too-many-requests') {
            throw Exception(
                'Trop de tentatives échouées. Veuillez réessayer plus tard');
          } else if (e.code == 'user-not-found') {
            throw Exception('Utilisateur non trouvé');
          }
        }
        rethrow;
      }

      // Changer le mot de passe
      try {
        await user.updatePassword(newPassword);
      } catch (e) {
        if (e is FirebaseAuthException) {
          if (e.code == 'weak-password') {
            throw Exception('Le nouveau mot de passe est trop faible');
          } else if (e.code == 'requires-recent-login') {
            throw Exception(
                'Veuillez vous reconnecter avant de changer votre mot de passe');
          }
        }
        rethrow;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors du changement de mot de passe: $e');
      }
      rethrow;
    }
  }

  // Récupérer les données du profil utilisateur
  Future<UserModel?> getUserProfile() async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();

      if (userDoc.exists) {
        return UserModel.fromMap(
          userDoc.data() as Map<String, dynamic>,
          currentUser.uid,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la récupération du profil: $e');
      }
      return null;
    }
  }

  // Mettre à jour le profil utilisateur
  Future<bool> updateUserProfile(UserModel updatedUser) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update(updatedUser.toMap());

      // Mettre à jour le displayName dans Firebase Auth si nécessaire
      if (updatedUser.displayName != null &&
          updatedUser.displayName != currentUser.displayName) {
        await currentUser.updateDisplayName(updatedUser.displayName);
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la mise à jour du profil: $e');
      }
      return false;
    }
  }

  // Mettre à jour la photo de profil
  Future<bool> updateProfilePicture(String imagePath) async {
    try {
      User? currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Créer une référence au stockage Firebase
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${currentUser.uid}.jpg');

      // Télécharger l'image
      final file = File(imagePath);
      await storageRef.putFile(file);

      // Obtenir l'URL de téléchargement
      final downloadURL = await storageRef.getDownloadURL();

      // Mettre à jour l'URL dans Firestore
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .update({'photoURL': downloadURL});

      // Mettre à jour l'URL dans Firebase Auth
      await currentUser.updatePhotoURL(downloadURL);

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la mise à jour de la photo de profil: $e');
      }
      return false;
    }
  }

  // Méthode pour tester la connexion à Firebase
  Future<bool> testDatabaseConnection() async {
    // Temporairement désactivé pendant le développement
    print('Test de connexion à Firebase...');
    print('   - Test de connexion temporairement désactivé');
    return true;
  }

  // Méthode de test pour écrire des données simples
  Future<bool> testWriteData() async {
    try {
      print('Test d\'écriture simple dans Firebase...');

      // Écrire un objet simple à la racine
      await _database.child('test').set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'Test d\'écriture'
      });

      // Vérifier si les données ont été écrites
      final testData = await _database.child('test').get();
      if (testData.exists) {
        print('Test d\'écriture réussi');
        return true;
      } else {
        print('Les données de test n\'ont pas été écrites');
        return false;
      }
    } catch (e) {
      print('Erreur lors du test d\'écriture: $e');
      return false;
    }
  }

  // Méthode pour initialiser les données de consommation
  Future<void> initializeConsumptionData() async {
    try {
      print('Début de l\'initialisation des données...');
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      // Vérifier si les données existent déjà
      final userData = await _firestore.collection('users').doc(user.uid).get();
      if (!userData.exists) {
        throw Exception('Données utilisateur non trouvées');
      }

      final userType = userData.data()?['userType'] as String?;
      if (userType != 'owner' && userType != 'tenant') {
        throw Exception('Type d\'utilisateur invalide');
      }

      print('Type d\'utilisateur: $userType');

      // Initialiser les données de base si nécessaire
      final consumptionRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('consumption_data')
          .doc('current');

      final consumptionData = await consumptionRef.get();
      if (!consumptionData.exists) {
        print('Initialisation des données de consommation...');

        // Générer des données de test réalistes
        final random = Random();
        final monthlyData = {
          'January': 250.0 + random.nextDouble() * 50,
          'February': 280.0 + random.nextDouble() * 50,
          'March': 300.0 + random.nextDouble() * 50,
          'April': 320.0 + random.nextDouble() * 50,
          'May': 350.0 + random.nextDouble() * 50,
          'June': 380.0 + random.nextDouble() * 50,
          'July': 400.0 + random.nextDouble() * 50,
          'August': 420.0 + random.nextDouble() * 50,
          'September': 380.0 + random.nextDouble() * 50,
          'October': 350.0 + random.nextDouble() * 50,
          'November': 300.0 + random.nextDouble() * 50,
          'December': 270.0 + random.nextDouble() * 50,
        };

        // Calculer les statistiques
        final values = monthlyData.values.toList();
        final average = values.reduce((a, b) => a + b) / values.length;
        final maximum = values.reduce((a, b) => a > b ? a : b);
        final minimum = values.reduce((a, b) => a < b ? a : b);
        final annualTotal = values.reduce((a, b) => a + b);

        final initialData = {
          'monthly_consumption': monthlyData,
          'statistics': {
            'average': average,
            'maximum': maximum,
            'minimum': minimum,
            'annual_total': annualTotal,
          },
          'last_updated': FieldValue.serverTimestamp(),
        };

        await consumptionRef.set(initialData);
        print('Données de consommation initialisées avec succès');
      } else {
        print('Les données de consommation existent déjà');
      }

      // Initialiser les données du compteur simulé
      print('Initialisation des données du compteur...');
      final meterRef = FirebaseDatabase.instance
          .ref()
          .child('compteurs')
          .child('compteur_simule_1');
      final meterData = await meterRef.get();

      if (!meterData.exists) {
        print('Initialisation des données du compteur...');
        await meterRef.set({
          'is_active': true,
          'last_reading': {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'power': 1500.0,
            'voltage': 220.0,
            'current': 6.8,
            'energy': 250.0,
          },
          'status': 'online',
        });
        print('Données du compteur initialisées avec succès');
      } else {
        print('Les données du compteur existent déjà');
      }

      print('Initialisation des données terminée avec succès');
    } catch (e) {
      print('Erreur lors de l\'initialisation des données: $e');
      throw Exception('Erreur lors de l\'initialisation des données: $e');
    }
  }

  // Méthode pour récupérer les données de consommation
  Future<Map<String, dynamic>> getConsumptionData(bool isOwner) async {
    try {
      if (currentUser == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      print('Récupération des données pour l\'utilisateur ${currentUser!.uid}');

      // Récupérer les données depuis Firestore
      final consumptionRef = _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('consumption_data')
          .doc('current');

      final consumptionDoc = await consumptionRef.get();

      if (!consumptionDoc.exists) {
        print('Aucune donnée de consommation trouvée');
        return {};
      }

      final data = consumptionDoc.data() as Map<String, dynamic>;
      print('Données récupérées: $data');

      // Récupérer les données du compteur simulé
      final meterRef = _database.child('compteurs').child('compteur_simule_1');
      final meterData = await meterRef.get();

      if (meterData.exists) {
        final meterInfo = Map<String, dynamic>.from(meterData.value as Map);
        data['smart_meter'] = {'compteur_simule_1': meterInfo};
      }

      return data;
    } catch (e) {
      print('Erreur lors de la récupération des données: $e');
      return {};
    }
  }

  // Méthode pour récupérer les données mensuelles
  Future<List<double>> getMonthlyData(bool isOwner) async {
    final data = await getConsumptionData(isOwner);
    final monthlyData = data['monthly_consumption'] as Map?;

    if (monthlyData != null) {
      return monthlyData.values
          .map((value) => (value as num).toDouble())
          .toList();
    }

    return List.filled(
        12, 0.0); // Retourner une liste de 12 zéros si pas de données
  }

  // Méthode pour récupérer les statistiques
  Future<Map<String, dynamic>> getStatistics(bool isOwner) async {
    final data = await getConsumptionData(isOwner);
    final stats = data['statistics'] as Map? ?? {};

    // S'assurer que toutes les clés nécessaires existent
    return {
      'average': stats['average'] ?? 0.0,
      'maximum': stats['maximum'] ?? 0.0,
      'minimum': stats['minimum'] ?? 0.0,
      'annual_total': stats['annual_total'] ?? 0.0,
    };
  }

  // Méthode pour récupérer les données du compteur intelligent
  Future<Map<String, dynamic>> getSmartMeterData(
      String meterId, bool isOwner) async {
    final data = await getConsumptionData(isOwner);
    final meterData =
        (data['smart_meter'] as Map?)?['compteur_simule_1'] as Map?;

    if (meterData != null) {
      return Map<String, dynamic>.from(meterData);
    }

    return {};
  }

  // Méthode pour vérifier l'état de l'authentification
  Future<Map<String, dynamic>> checkAuthState() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Aucun utilisateur connecté');
        return {
          'isAuthenticated': false,
          'userId': null,
          'email': null,
          'isEmailVerified': false,
          'hasValidToken': false,
          'hasFirestoreData': false,
          'userType': null,
        };
      }

      print('Vérification de l\'état d\'authentification pour: ${user.email}');

      // Forcer le rafraîchissement du token
      final token = await user.getIdToken(true);
      print('Token rafraîchi: ${token?.substring(0, 10) ?? 'null'}...');

      // Vérifier si l'utilisateur existe dans Firestore
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final hasFirestoreData = userDoc.exists && userDoc.data() != null;

      if (!hasFirestoreData) {
        print('Utilisateur non trouvé dans Firestore');
        await signOut();
        return {
          'isAuthenticated': false,
          'userId': null,
          'email': null,
          'isEmailVerified': false,
          'hasValidToken': false,
          'hasFirestoreData': false,
          'userType': null,
        };
      }

      final userData = userDoc.data()!;
      final userType = userData['userType'] as String?;
      print('Type d\'utilisateur trouvé dans Firestore: $userType');

      if (userType == null || (userType != 'owner' && userType != 'tenant')) {
        print('Type d\'utilisateur invalide: $userType');
        await signOut();
        return {
          'isAuthenticated': false,
          'userId': null,
          'email': null,
          'isEmailVerified': false,
          'hasValidToken': false,
          'hasFirestoreData': false,
          'userType': null,
        };
      }

      print('Vérification d\'authentification réussie pour: ${user.email}');
      print('Type d\'utilisateur: $userType');
      print('Nom: ${userData['name'] as String? ?? 'Non défini'}');

      return {
        'isAuthenticated': true,
        'userId': user.uid,
        'email': user.email,
        'isEmailVerified': user.emailVerified,
        'hasValidToken': true,
        'hasFirestoreData': true,
        'userType': userType,
        'name': userData['name'] as String? ?? 'Utilisateur',
      };
    } catch (e) {
      print('Erreur lors de la vérification de l\'authentification: $e');
      await signOut();
      return {
        'isAuthenticated': false,
        'userId': null,
        'email': null,
        'isEmailVerified': false,
        'hasValidToken': false,
        'hasFirestoreData': false,
        'userType': null,
      };
    }
  }

  // Méthode pour récupérer le type d'utilisateur par UID
  Future<String> getUserTypeByUid(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        throw Exception('Utilisateur non trouvé');
      }
      final userData = userDoc.data();
      final userType = userData?['userType'] as String?;
      if (userType == null) {
        throw Exception('Type d\'utilisateur non défini');
      }
      return userType;
    } catch (e) {
      print('Erreur lors de la récupération du type d\'utilisateur: $e');
      rethrow;
    }
  }

  // Méthode pour récupérer les données du compteur
  Future<Map<String, dynamic>> getMeterData(String meterId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Utilisateur non connecté');

      final userType = await getUserTypeByUid(user.uid);
      final databaseRef = FirebaseDatabase.instance.ref();

      final meterRef = databaseRef
          .child('users')
          .child(user.uid)
          .child('consumption')
          .child(userType)
          .child('smart_meter')
          .child('compteur_simule_1');

      final snapshot = await meterRef.get();
      if (!snapshot.exists) {
        throw Exception('Compteur non trouvé');
      }

      return Map<String, dynamic>.from(snapshot.value as Map);
    } catch (e) {
      print('Erreur lors de la récupération des données du compteur: $e');
      rethrow;
    }
  }

  // Méthode de débogage pour l'authentification
  Future<void> debugAuthentication() async {
    try {
      print('\n=== DÉBOGAGE AUTHENTIFICATION ===');

      // 1. Vérifier l'état de la connexion Firebase
      print('1. Connexion Firebase:');
      final isConnected = await testDatabaseConnection();
      print('   - Connexion établie: $isConnected');

      // 2. Vérifier l'utilisateur actuel
      print('2. Utilisateur actuel:');
      final user = _auth.currentUser;
      print('   - Utilisateur connecté: ${user != null}');
      if (user != null) {
        print('   - UID: ${user.uid}');
        print('   - Email: ${user.email}');
        print('   - Email vérifié: ${user.emailVerified}');

        // 3. Vérifier les données Firestore
        print('3. Données Firestore:');
        try {
          final userDoc =
              await _firestore.collection('users').doc(user.uid).get();
          print('   - Document existe: ${userDoc.exists}');
          if (userDoc.exists) {
            final userData = userDoc.data();
            print('   - Type d\'utilisateur: ${userData?['userType']}');
            print('   - Nom: ${userData?['name']}');
          }
        } catch (e) {
          print('   - Erreur Firestore: $e');
        }

        // 4. Vérifier les données Realtime Database
        print('4. Données Realtime Database:');
        try {
          final dbRef = _database.child('users').child(user.uid);
          final dbSnapshot = await dbRef.get();
          print('   - Données existent: ${dbSnapshot.exists}');
          if (dbSnapshot.exists) {
            print('   - Valeur: ${dbSnapshot.value}');
          }
        } catch (e) {
          print('   - Erreur Database: $e');
        }
      }

      print('=== FIN DÉBOGAGE ===\n');
    } catch (e) {
      print('Erreur lors du débogage: $e');
    }
  }

  // Méthode pour réinitialiser complètement l'authentification
  Future<void> resetAuthentication() async {
    try {
      print('Réinitialisation de l\'authentification...');

      // 1. Déconnexion de l'utilisateur actuel
      await signOut();

      // 2. Effacer les caches locaux
      await _auth.signOut();

      // 3. Vérifier l'état après réinitialisation
      final user = _auth.currentUser;
      print(
          'État après réinitialisation: ${user == null ? "Déconnecté" : "Toujours connecté"}');

      print('Réinitialisation terminée');
      return;
    } catch (e) {
      print('Erreur lors de la réinitialisation: $e');
      rethrow;
    }
  }

  DatabaseReference getMeterRef(String meterId) {
    return FirebaseDatabase.instance.ref('compteurs/$meterId');
  }

  // Méthode pour initialiser les données d'un locataire
  Future<void> initializeTenantData(String apartmentId) async {
    try {
      print('Initialisation des données du locataire...');

      // Vérifier si l'appartement existe
      final apartmentRef = _database.child('apartments').child(apartmentId);
      final apartmentData = await apartmentRef.get();

      if (!apartmentData.exists) {
        throw Exception('Appartement non trouvé');
      }

      // Initialiser les données de consommation de l'appartement
      final consumptionRef = apartmentRef.child('consumption');
      final consumptionData = await consumptionRef.get();

      if (!consumptionData.exists) {
        print(
            'Initialisation des données de consommation de l\'appartement...');
        await consumptionRef.set({
          'current_reading': 0.0,
          'last_reading': {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'value': 0.0,
          },
          'status': 'active',
          'monthly_data': {
            'January': 0.0,
            'February': 0.0,
            'March': 0.0,
            'April': 0.0,
            'May': 0.0,
            'June': 0.0,
            'July': 0.0,
            'August': 0.0,
            'September': 0.0,
            'October': 0.0,
            'November': 0.0,
            'December': 0.0,
          },
          'statistics': {
            'average': 0.0,
            'maximum': 0.0,
            'minimum': 0.0,
            'total': 0.0,
          },
        });
        print('Données de consommation initialisées avec succès');
      } else {
        print('Les données de consommation existent déjà');
      }

      print('Initialisation des données du locataire terminée avec succès');
    } catch (e) {
      print('Erreur lors de l\'initialisation des données du locataire: $e');
      throw Exception(
          'Erreur lors de l\'initialisation des données du locataire: $e');
    }
  }

  // Méthode pour assigner un appartement à un locataire
  Future<void> assignApartmentToTenant(
      String tenantId, String apartmentId) async {
    try {
      print(
          'Tentative d\'assignation de l\'appartement $apartmentId au locataire $tenantId');

      // Vérifier si l'appartement existe
      final apartmentRef = _database.child('apartments').child(apartmentId);
      final apartmentData = await apartmentRef.get();

      if (!apartmentData.exists) {
        throw Exception('Appartement non trouvé');
      }

      // Vérifier si le locataire existe
      final tenantRef = _firestore.collection('users').doc(tenantId);
      final tenantData = await tenantRef.get();

      if (!tenantData.exists) {
        throw Exception('Locataire non trouvé');
      }

      // Vérifier que c'est bien un locataire
      final userType = tenantData.data()?['userType'] as String?;
      if (userType != 'tenant') {
        throw Exception('L\'utilisateur n\'est pas un locataire');
      }

      // Mettre à jour les données du locataire
      await tenantRef.update({
        'apartmentId': apartmentId,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Initialiser les données de consommation pour l'appartement
      await initializeTenantData(apartmentId);

      print('Appartement assigné avec succès au locataire');
    } catch (e) {
      print('Erreur lors de l\'assignation de l\'appartement: $e');
      throw Exception('Erreur lors de l\'assignation de l\'appartement: $e');
    }
  }
}
