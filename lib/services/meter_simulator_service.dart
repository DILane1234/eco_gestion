import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:eco_gestion/services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MeterSimulatorService {
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _simulationTimer;
  final Random _random = Random();

  // Méthode pour démarrer la simulation
  Future<void> startSimulation() async {
    try {
      // Démarrer la simulation
      _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _simulateMeterData();
      });
    } catch (e) {
      print('Erreur lors du démarrage de la simulation: $e');
      rethrow;
    }
  }

  // Arrêter la simulation
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  // Méthode pour simuler les données du compteur
  Future<void> _simulateMeterData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userType = await _firebaseService.getUserTypeByUid(user.uid);
      final databaseRef = FirebaseDatabase.instance.ref();

      final meterRef = databaseRef
          .child('users')
          .child(user.uid)
          .child('consumption')
          .child(userType)
          .child('smart_meter')
          .child('compteur_simule_1');

      // Générer des valeurs aléatoires réalistes
      final voltage = 220.0 + (_random.nextDouble() * 20 - 10); // 210-230V
      final current = 5.0 + (_random.nextDouble() * 10); // 5-15A
      final power = voltage * current; // Puissance en watts
      final powerFactor = 0.85 + (_random.nextDouble() * 0.15); // 0.85-1.0
      final frequency = 49.8 + (_random.nextDouble() * 0.4); // 49.8-50.2Hz
      final energy = _calculateEnergy(); // Énergie en kWh

      final data = {
        'is_active': true,
        'current_power': power,
        'last_reading': {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'value': power,
          'voltage': voltage,
          'current': current,
          'power': power,
          'energy': energy,
          'powerFactor': powerFactor,
          'frequency': frequency
        },
        'name': 'Compteur Simulé',
        'roomId': 'salon',
        'isOnline': true,
      };

      await meterRef.update(data);
    } catch (e) {
      print('Erreur lors de la simulation des données: $e');
    }
  }

  // Simuler une accumulation d'énergie réaliste
  double _calculateEnergy() {
    // Simuler une consommation qui augmente progressivement
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final hoursSinceStartOfDay = now.difference(startOfDay).inHours;

    // Base de 0.5 kWh par heure avec variation aléatoire
    return hoursSinceStartOfDay * (0.5 + _random.nextDouble() * 0.2);
  }
}
