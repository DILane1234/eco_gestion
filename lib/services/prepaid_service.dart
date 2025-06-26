import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/prepaid_system.dart';
import 'notification_service.dart';

class PrepaidService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();

  // Prix par défaut du kWh en FCFA
  static const double DEFAULT_KWH_PRICE = 100.0;

  // Initialiser le système prépayé pour un compteur
  Future<void> initializePrepaidSystem(String meterId, double amount) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final energyCredit =
        PrepaidSystem.calculateEnergyFromAmount(amount, DEFAULT_KWH_PRICE);

    final prepaidSystem = PrepaidSystem(
      meterId: meterId,
      creditAmount: amount,
      energyCredit: energyCredit,
      consumedEnergy: 0.0,
      remainingEnergy: energyCredit,
      isActive: true,
      lastUpdate: DateTime.now(),
      kWhPrice: DEFAULT_KWH_PRICE,
      lowCreditAlert: false,
    );

    // Sauvegarder dans Firebase Realtime Database
    await _database.ref('prepaid_systems/$meterId').set(prepaidSystem.toMap());

    // Sauvegarder l'historique dans Firestore
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('prepaid_history')
        .add({
      'meterId': meterId,
      'amount': amount,
      'energyCredit': energyCredit,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'initialization',
    });
  }

  // Mettre à jour la consommation
  Future<void> updateConsumption(String meterId, double newConsumption) async {
    final prepaidRef = _database.ref('prepaid_systems/$meterId');
    final snapshot = await prepaidRef.get();

    if (!snapshot.exists) {
      throw Exception('Système prépayé non trouvé');
    }

    final prepaidSystem = PrepaidSystem.fromMap(
      Map<String, dynamic>.from(snapshot.value as Map),
    );

    final updatedSystem = prepaidSystem.updateConsumption(newConsumption);
    await prepaidRef.update(updatedSystem.toMap());

    // Vérifier si une notification est nécessaire
    if (updatedSystem.lowCreditAlert && !prepaidSystem.lowCreditAlert) {
      await _notificationService.sendLowCreditAlert(
        meterId,
        updatedSystem.remainingEnergy,
      );
    }

    if (!updatedSystem.isActive && prepaidSystem.isActive) {
      await _notificationService.sendPowerCutAlert(meterId);
    }
  }

  // Recharger le compte
  Future<void> rechargeAccount(String meterId, double amount) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    final prepaidRef = _database.ref('prepaid_systems/$meterId');
    final snapshot = await prepaidRef.get();

    if (!snapshot.exists) {
      throw Exception('Système prépayé non trouvé');
    }

    final prepaidSystem = PrepaidSystem.fromMap(
      Map<String, dynamic>.from(snapshot.value as Map),
    );

    final newEnergyCredit =
        PrepaidSystem.calculateEnergyFromAmount(amount, prepaidSystem.kWhPrice);
    final updatedSystem = PrepaidSystem(
      meterId: meterId,
      creditAmount: amount,
      energyCredit: newEnergyCredit,
      consumedEnergy: 0.0,
      remainingEnergy: newEnergyCredit,
      isActive: true,
      lastUpdate: DateTime.now(),
      kWhPrice: prepaidSystem.kWhPrice,
      lowCreditAlert: false,
    );

    await prepaidRef.update(updatedSystem.toMap());

    // Sauvegarder l'historique dans Firestore
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('prepaid_history')
        .add({
      'meterId': meterId,
      'amount': amount,
      'energyCredit': newEnergyCredit,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'recharge',
    });
  }

  // Détecter une tentative de fraude
  Future<void> detectFraud(String meterId, String details) async {
    await _notificationService.sendFraudAlert(meterId, details);

    // Sauvegarder l'incident dans Firestore
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('fraud_incidents')
          .add({
        'meterId': meterId,
        'details': details,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // Obtenir l'état actuel du système prépayé
  Stream<PrepaidSystem> getPrepaidSystemStream(String meterId) {
    return _database.ref('prepaid_systems/$meterId').onValue.map((event) {
      if (!event.snapshot.exists) {
        throw Exception('Système prépayé non trouvé');
      }
      return PrepaidSystem.fromMap(
        Map<String, dynamic>.from(event.snapshot.value as Map),
      );
    });
  }

  // Obtenir l'historique des recharges
  Stream<QuerySnapshot> getRechargeHistory(String meterId) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté');

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('prepaid_history')
        .where('meterId', isEqualTo: meterId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
