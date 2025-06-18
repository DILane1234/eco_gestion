import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/firebase_service.dart';

class SmartMeterCard extends StatefulWidget {
  final String meterId;
  final bool isOwner;
  final VoidCallback? onTap;

  const SmartMeterCard({
    super.key,
    required this.meterId,
    this.isOwner = false,
    this.onTap,
  });

  @override
  State<SmartMeterCard> createState() => _SmartMeterCardState();
}

class _SmartMeterCardState extends State<SmartMeterCard> {
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
      return const Card(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Card(
        child: Center(
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
        ),
      );
    }

    if (_meterData == null) {
      return const Card(
        child: Center(
          child: Text('Aucune donnée disponible'),
        ),
      );
    }

    final lastReading =
        _meterData!['last_reading'] as Map<String, dynamic>? ?? {};

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec nom et état
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.electric_meter,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compteur ${widget.meterId}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (_meterData!['is_active'] ?? false)
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: (_meterData!['is_active'] ?? false)
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                color: (_meterData!['is_active'] ?? false)
                                    ? Colors.green.shade500
                                    : Colors.red.shade500,
                                size: 8,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                (_meterData!['is_active'] ?? false)
                                    ? 'En ligne'
                                    : 'Hors ligne',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: (_meterData!['is_active'] ?? false)
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onTap != null)
                    Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 16),
              // Grille des données
              _buildDataGrid(_meterData),
              const SizedBox(height: 16),
              Text(
                'Dernière mise à jour: ${DateTime.fromMillisecondsSinceEpoch(lastReading['timestamp'] ?? 0).toString().substring(0, 16)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
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
    String title,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
