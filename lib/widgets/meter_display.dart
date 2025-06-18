import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eco_gestion/services/firebase_service.dart';

class MeterDisplay extends StatefulWidget {
  final String meterId;

  const MeterDisplay({super.key, required this.meterId});

  @override
  State<MeterDisplay> createState() => _MeterDisplayState();
}

class _MeterDisplayState extends State<MeterDisplay> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  Map<String, dynamic>? _meterData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMeterData();
  }

  Future<void> _loadMeterData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Vérifier l'état d'authentification
      final authState = await _firebaseService.checkAuthState();
      if (!authState['isAuthenticated']) {
        throw Exception('Utilisateur non authentifié');
      }

      // Récupérer le type d'utilisateur
      final userType = authState['userType'] as String?;
      if (userType == null) {
        throw Exception('Type d\'utilisateur non défini');
      }

      // Récupérer les données du compteur
      final data = await _firebaseService.getMeterData(widget.meterId);
      if (mounted) {
        setState(() {
          _meterData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des données du compteur: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Erreur de chargement des données',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMeterData,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_meterData == null) {
      return const Center(
        child: Text('Aucune donnée disponible'),
      );
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _meterData!['name'] ?? 'Compteur ${widget.meterId}',
              style: Theme.of(context).textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            _buildDataGrid(_meterData),
            const SizedBox(height: 16),
            _buildStatusIndicators(_meterData!),
          ],
        ),
      ),
    );
  }

  Widget _buildDataGrid(Map<String, dynamic>? data) {
    if (data == null) {
      return const Center(
        child: Text('Aucune donnée disponible'),
      );
    }

    // Conversion sécurisée des données
    final Map<String, dynamic> safeData = {};
    data.forEach((key, value) {
      if (key is String) {
        if (value is Map) {
          // Conversion récursive des sous-maps
          final Map<String, dynamic> subMap = {};
          value.forEach((subKey, subValue) {
            if (subKey is String) {
              subMap[subKey] = subValue;
            }
          });
          safeData[key] = subMap;
        } else {
          safeData[key] = value;
        }
      }
    });

    final lastReading = safeData['last_reading'] as Map<String, dynamic>?;
    if (lastReading == null) {
      return const Center(
        child: Text('Aucune lecture disponible'),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildDataTile(
          'Puissance',
          '${lastReading['power']?.toStringAsFixed(1) ?? '0'}',
          'W',
          Icons.power,
          Colors.blue,
        ),
        _buildDataTile(
          'Tension',
          '${lastReading['voltage']?.toStringAsFixed(1) ?? '0'}',
          'V',
          Icons.electric_bolt,
          Colors.orange,
        ),
        _buildDataTile(
          'Courant',
          '${lastReading['current']?.toStringAsFixed(2) ?? '0'}',
          'A',
          Icons.electric_meter,
          Colors.green,
        ),
        _buildDataTile(
          'Énergie',
          '${lastReading['energy']?.toStringAsFixed(1) ?? '0'}',
          'kWh',
          Icons.energy_savings_leaf,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildDataTile(
      String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value $unit',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicators(Map<String, dynamic> data) {
    final isOnline = data['is_active'] ?? false;
    final isActive = data['is_active'] ?? false;
    final hasError = data['has_error'] ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          child: _buildStatusChip(
            'En ligne',
            isOnline,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusChip(
            'Actif',
            isActive,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatusChip(
            'Erreur',
            hasError,
            Colors.red,
            inverted: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(
    String label,
    bool status,
    Color color, {
    bool inverted = false,
  }) {
    final isActive = inverted ? !status : status;
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.white : Colors.grey.shade800,
          fontSize: 12,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      backgroundColor: isActive ? color : Colors.grey.shade200,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
