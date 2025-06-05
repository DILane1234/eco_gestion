import 'dart:async';
import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:eco_gestion/services/firebase_service.dart';

class MeterSimulatorService {
  final FirebaseService _firebaseService = FirebaseService();
  Timer? _simulationTimer;
  final Random _random = Random();

  // Méthode pour démarrer la simulation
  Future<void> startSimulation(String meterId) async {
    // D'abord, initialiser la structure du compteur
    await _firebaseService.initializeMeterStructure(meterId,
        name: 'Compteur Simulé', roomId: 'salon');

    // Arrêter toute simulation existante
    stopSimulation();

    // Démarrer une nouvelle simulation avec mise à jour toutes les 5 secondes
    _simulationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateSimulatedData(meterId);
    });
  }

  // Arrêter la simulation
  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  // Générer des données simulées réalistes
  void _updateSimulatedData(String meterId) {
    // Simuler des variations réalistes
    final baseVoltage = 230.0;
    final basePower = 2000.0; // 2kW en moyenne

    final data = {
      'frequency': 50.0 + _random.nextDouble() * 0.4 - 0.2, // 49.8-50.2 Hz
      'powerFactor': 0.92 + _random.nextDouble() * 0.06, // 0.92-0.98
      'current': (basePower / baseVoltage) *
          (0.9 + _random.nextDouble() * 0.2), // Variation ±10%
      'power': basePower * (0.8 + _random.nextDouble() * 0.4), // Variation ±20%
      'energy': _calculateEnergy(), // Cumul de l'énergie
      'voltage':
          baseVoltage * (0.95 + _random.nextDouble() * 0.1), // 218.5-241.5V
      'isOnline': true,
      'isActive': true,
      'lastUpdate': ServerValue.timestamp,
    };

    // Simuler occasionnellement une puissance élevée pour tester les alertes
    if (_random.nextDouble() < 0.1) {
      // 10% de chance
      data['power'] =
          4100.0 + _random.nextDouble() * 500; // Déclenchera une alerte
    }

    // Mettre à jour dans Firebase
    FirebaseDatabase.instance.ref('compteurs').child(meterId).update(data);
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
