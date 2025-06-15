import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eco_gestion/models/user_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';

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

      // 1. Tentative de connexion avec Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user == null) {
        throw Exception("Erreur d'authentification : utilisateur non trouvé");
      }

      // 2. Vérifier si l'utilisateur existe dans Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception(
            'Compte utilisateur incomplet. Veuillez contacter le support.');
      }

      final userData = userDoc.data()!;
      final userType = userData['userType'] as String?;

      if (userType != 'owner' && userType != 'tenant') {
        throw Exception('Type d\'utilisateur non valide');
      }

      print('Connexion réussie pour: $email (${userType})');

      return {
        'user': userCredential.user,
        'userType': userType,
        'userData': userData,
      };
    } on FirebaseAuthException catch (e) {
      print('Erreur FirebaseAuth: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          throw Exception('Aucun compte ne correspond à cet e-mail.');
        case 'wrong-password':
          throw Exception('Mot de passe incorrect.');
        case 'invalid-email':
          throw Exception('Format d\'e-mail invalide.');
        case 'user-disabled':
          throw Exception('Ce compte a été désactivé.');
        case 'too-many-requests':
          throw Exception('Trop de tentatives. Réessayez plus tard.');
        default:
          throw Exception(e.message ?? 'Erreur de connexion inconnue.');
      }
    } catch (e) {
      print('Erreur de connexion: $e');
      throw Exception('Erreur de connexion. Veuillez réessayer.');
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
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
    try {
      print('Test de connexion à Firebase...');
      await _database.child('.info/connected').get();
      print('Connexion à Firebase réussie');
      return true;
    } catch (e) {
      print('Erreur de connexion à Firebase: $e');
      return false;
    }
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

      // Test d'écriture simple d'abord
      final canWrite = await testWriteData();
      if (!canWrite) {
        throw Exception('Impossible d\'écrire dans Firebase');
      }

      // Vérifier si l'utilisateur est connecté
      if (currentUser == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      print('Utilisateur connecté: ${currentUser!.uid}');

      // Vérifier le type d'utilisateur
      final userType = await getUserType();
      if (userType == null) {
        throw Exception('Type d\'utilisateur non trouvé');
      }

      print('Type d\'utilisateur: $userType');

      // Structure simplifiée pour le test
      final testData = {
        'lastUpdate': DateTime.now().millisecondsSinceEpoch,
        'type': userType
      };

      // Tester l'écriture avec des données simples d'abord
      print('Test d\'écriture des données simples...');
      await _database
          .child('users')
          .child(currentUser!.uid)
          .child('test')
          .set(testData);

      // Si le test réussit, écrire les données complètes
      final consumptionData = {
        'consumption': {
          userType: {
            'monthly_consumption': {
              'January': 120,
              'February': 140,
              'March': 160,
              'April': 180,
              'May': 200,
              'June': 220,
              'July': 250,
              'August': 230,
              'September': 210,
              'October': 190,
              'November': 170,
              'December': 150
            },
            'statistics': {
              'average': 195,
              'maximum': 250,
              'minimum': 120,
              'annual_total': 2320
            },
            'smart_meter': {
              'compteur_simule_1': {
                'current_power': 2248.51,
                'is_active': true,
                'last_reading': {
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                  'value': 2248.51,
                  'voltage': 237.29,
                  'current': 9.19,
                  'power': 2248.51,
                  'energy': 8.50,
                  'powerFactor': 0.97,
                  'frequency': 49.85
                }
              }
            }
          }
        }
      };

      print('Écriture des données complètes...');
      await _database
          .child('users')
          .child(currentUser!.uid)
          .set(consumptionData);

      // Vérifier si les données ont été écrites
      final verificationData =
          await _database.child('users').child(currentUser!.uid).get();
      if (!verificationData.exists) {
        throw Exception('Les données n\'ont pas été écrites dans Firebase');
      }

      print('Données sauvegardées et vérifiées avec succès');
      print('Contenu des données: ${verificationData.value}');
    } catch (e) {
      print('Erreur lors de l\'initialisation des données: $e');
      rethrow;
    }
  }

  // Méthode pour récupérer les données de consommation
  Future<Map<String, dynamic>> getConsumptionData(bool isOwner) async {
    try {
      if (currentUser == null) {
        throw Exception('Aucun utilisateur connecté');
      }

      final userType = isOwner ? 'owner' : 'tenant';
      print(
          'Récupération des données pour l\'utilisateur ${currentUser!.uid} (type: $userType)');

      final snapshot = await _database
          .child('users')
          .child(currentUser!.uid)
          .child('consumption')
          .child(userType)
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        print('Données récupérées: $data');
        return data;
      }

      print('Aucune donnée trouvée pour l\'utilisateur ${currentUser!.uid}');
      return {};
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

    return [];
  }

  // Méthode pour récupérer les statistiques
  Future<Map<String, dynamic>> getStatistics(bool isOwner) async {
    final data = await getConsumptionData(isOwner);
    return Map<String, dynamic>.from(data['statistics'] as Map? ?? {});
  }

  // Méthode pour récupérer les données du compteur intelligent
  Future<Map<String, dynamic>> getSmartMeterData(
      String meterId, bool isOwner) async {
    final data = await getConsumptionData(isOwner);
    final meterData = (data['compteurs'] as Map?)?[meterId] as Map?;

    if (meterData != null) {
      return Map<String, dynamic>.from(meterData);
    }

    return {};
  }

  // Méthode pour vérifier l'état de l'authentification
  Future<Map<String, dynamic>> checkAuthState() async {
    try {
      final User? user = _auth.currentUser;

      if (user != null) {
        // Vérifier si le token est valide
        final idToken = await user.getIdToken();

        // Vérifier les informations dans Firestore
        final userDoc =
            await _firestore.collection('users').doc(user.uid).get();
        final userData = userDoc.data();

        print('=== État de l\'authentification ===');
        print('UID: ${user.uid}');
        print('Email: ${user.email}');
        print('Email vérifié: ${user.emailVerified}');
        print('Token valide: ${idToken != null}');
        print('Données Firestore existantes: ${userDoc.exists}');
        if (userData != null) {
          print('Type d\'utilisateur: ${userData['userType']}');
        }
        print('================================');

        return {
          'isAuthenticated': true,
          'uid': user.uid,
          'email': user.email,
          'emailVerified': user.emailVerified,
          'hasValidToken': idToken != null,
          'hasFirestoreData': userDoc.exists,
          'userType': userData?['userType'],
        };
      } else {
        print('=== État de l\'authentification ===');
        print('Aucun utilisateur connecté');
        print('================================');

        return {
          'isAuthenticated': false,
          'error': 'Aucun utilisateur connecté'
        };
      }
    } catch (e) {
      print('=== Erreur d\'authentification ===');
      print('Erreur: $e');
      print('================================');

      return {'isAuthenticated': false, 'error': e.toString()};
    }
  }

  // Méthode pour initialiser ou mettre à jour la structure d'un compteur
  Future<void> initializeMeterStructure(String meterId,
      {String? name, String? roomId}) async {
    try {
      final DatabaseReference meterRef =
          FirebaseDatabase.instance.ref('compteurs/$meterId');

      // Structure complète d'un compteur avec des valeurs par défaut
      final meterData = {
        'name': name ?? 'Compteur $meterId',
        'roomId': roomId,
        'frequency': 50.0,
        'powerFactor': 0.0,
        'current': 0.0,
        'power': 0.0,
        'energy': 0.0,
        'voltage': 230.0,
        'isOnline': false,
        'isActive': true,
        'lastUpdate': ServerValue.timestamp,
        'settings': {
          'maxPower': 4500.0, // Puissance maximale en watts
          'alertThreshold': 4000.0, // Seuil d'alerte en watts
          'samplingRate': 60, // Taux d'échantillonnage en secondes
        },
        'status': {
          'hasError': false,
          'errorCode': null,
          'lastMaintenance': ServerValue.timestamp,
        }
      };

      // Utiliser update au lieu de set pour ne pas écraser les données existantes
      await meterRef.update(meterData);

      print(
          'Structure du compteur $meterId initialisée/mise à jour avec succès');
    } catch (e) {
      print('Erreur lors de l\'initialisation du compteur: $e');
      rethrow;
    }
  }

  // Méthode pour récupérer les données complètes d'un compteur
  Future<Map<String, dynamic>> getMeterData(String meterId) async {
    final snapshot =
        await FirebaseDatabase.instance.ref('compteurs/$meterId').get();
    return snapshot.value as Map<String, dynamic>;
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
}
