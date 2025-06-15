import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../services/auth_service.dart';

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
  final AuthService _authService = AuthService();
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final hasAccess = await _authService.canAccessMeter(widget.meterId);
    if (mounted) {
      setState(() {
        _hasAccess = hasAccess;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAccess) {
      return const Card(
        child: Center(
          child: Text('Accès non autorisé'),
        ),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream:
          FirebaseDatabase.instance.ref('compteurs/${widget.meterId}').onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Erreur Firebase: ${snapshot.error}');
          return Card(
            child: Center(
              child: Text('Erreur: ${snapshot.error}'),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Card(
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final meter =
            Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

        return Card(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                color: (meter['is_active'] ?? false)
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (meter['is_active'] ?? false)
                                      ? Colors.green.shade200
                                      : Colors.red.shade200,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    color: (meter['is_active'] ?? false)
                                        ? Colors.green.shade500
                                        : Colors.red.shade500,
                                    size: 8,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    (meter['is_active'] ?? false)
                                        ? 'En ligne'
                                        : 'Hors ligne',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: (meter['is_active'] ?? false)
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
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    children: [
                      _buildDataTile(
                        'Puissance',
                        '${((meter['current_power'] ?? 0) / 1000).toStringAsFixed(2)}',
                        'kW',
                        Icons.power,
                        Colors.blue,
                      ),
                      if (meter['last_reading'] != null) ...[
                        _buildDataTile(
                          'Dernière lecture',
                          '${((meter['last_reading']['value'] ?? 0) / 1000).toStringAsFixed(2)}',
                          'kW',
                          Icons.history,
                          Colors.orange,
                        ),
                      ],
                    ],
                  ),
                  if (meter['last_reading'] != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Dernière mise à jour: ${DateTime.fromMillisecondsSinceEpoch(meter['last_reading']['timestamp'] ?? 0).toString().substring(0, 16)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
