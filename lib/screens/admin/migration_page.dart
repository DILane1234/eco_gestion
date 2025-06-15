import 'package:flutter/material.dart';
import '../../services/migration_service.dart';

class MigrationPage extends StatefulWidget {
  const MigrationPage({super.key});

  @override
  State<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends State<MigrationPage> {
  final MigrationService _migrationService = MigrationService();
  bool _isMigrating = false;
  String _status = '';

  Future<void> _startMigration() async {
    setState(() {
      _isMigrating = true;
      _status = 'Migration en cours...';
    });

    try {
      await _migrationService.migrateMetersData();
      setState(() {
        _status = 'Migration terminée avec succès!';
      });
    } catch (e) {
      setState(() {
        _status = 'Erreur lors de la migration: $e';
      });
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration des données'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _status,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isMigrating ? null : _startMigration,
                child: Text(_isMigrating
                    ? 'Migration en cours...'
                    : 'Démarrer la migration'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
