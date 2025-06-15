import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class SmartMeterService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // Récupérer les données actuelles du compteur
  Future<Map<String, dynamic>> getMeterData(String meterId) async {
    try {
      final snapshot = await _database.child('compteurs/$meterId').get();

      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      } else {
        return {};
      }
    } catch (e) {
      print('Erreur lors de la récupération des données: $e');
      return {};
    }
  }

  // Écouter les mises à jour en temps réel
  Stream<Map<String, dynamic>> getMeterDataStream(String meterId) {
    return _database.child('compteurs/$meterId').onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        return Map<String, dynamic>.from(event.snapshot.value as Map);
      } else {
        return {};
      }
    });
  }

  // Allumer ou éteindre le compteur
  Future<void> setMeterPower(String meterId, bool isOn) async {
    try {
      await _database.child('compteurs/$meterId/isOn').set(isOn);
    } catch (e) {
      print('Erreur lors de la modification de l\'état: $e');
      rethrow;
    }
  }

  // Réinitialiser le compteur
  Future<void> resetMeter(String meterId) async {
    try {
      await _database.child('compteurs/$meterId/reset').set(true);
      // Généralement, cette valeur est remise à false par le compteur lui-même
      // après avoir effectué la réinitialisation
    } catch (e) {
      print('Erreur lors de la réinitialisation: $e');
      rethrow;
    }
  }
}
