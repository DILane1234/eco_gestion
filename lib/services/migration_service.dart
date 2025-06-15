import 'package:firebase_database/firebase_database.dart';

class MigrationService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<void> migrateMetersData() async {
    try {
      // Récupérer les données de l'ancien chemin
      final snapshot = await _database.ref('compteurs').get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);

        // Migrer chaque compteur vers le nouveau chemin
        for (var entry in data.entries) {
          final meterId = entry.key;
          final meterData = entry.value;

          // Copier les données vers le nouveau chemin
          await _database.ref('smart_meter/$meterId').set(meterData);

          print('Migration réussie pour le compteur: $meterId');
        }

        // Une fois la migration terminée, vous pouvez supprimer l'ancien chemin
        // await _database.ref('compteurs').remove();
        // print('Ancien chemin supprimé');
      }
    } catch (e) {
      print('Erreur lors de la migration: $e');
      rethrow;
    }
  }
}
