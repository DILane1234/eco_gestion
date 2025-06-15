import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class MeterDisplay extends StatelessWidget {
  final String meterId;

  const MeterDisplay({super.key, required this.meterId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref('compteurs').child(meterId).onValue,
      builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Erreur de chargement des données'),
          );
        }

        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final data =
            Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);

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
                  data['name'] ?? 'Compteur $meterId',
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                _buildDataGrid(data),
                const SizedBox(height: 16),
                _buildStatusIndicators(data),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDataGrid(Map<String, dynamic> data) {
    final formatter = NumberFormat("#,##0.00", "fr_FR");

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      childAspectRatio: 2.0,
      mainAxisSpacing: 12,
      crossAxisSpacing: 8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildDataItem(
          'Puissance',
          '${formatter.format(data['power'] ?? 0)} W',
          Icons.bolt,
        ),
        _buildDataItem(
          'Énergie',
          '${formatter.format(data['energy'] ?? 0)} kWh',
          Icons.energy_savings_leaf,
        ),
        _buildDataItem(
          'Tension',
          '${formatter.format(data['voltage'] ?? 0)} V',
          Icons.electric_meter,
        ),
        _buildDataItem(
          'Courant',
          '${formatter.format(data['current'] ?? 0)} A',
          Icons.electric_bolt,
        ),
        _buildDataItem(
          'Fréquence',
          '${formatter.format(data['frequency'] ?? 0)} Hz',
          Icons.waves,
        ),
        _buildDataItem(
          'Facteur de puissance',
          formatter.format(data['powerFactor'] ?? 0),
          Icons.speed,
        ),
      ],
    );
  }

  Widget _buildDataItem(String label, String value, IconData icon) {
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
              value,
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
    final isOnline = data['isOnline'] ?? false;
    final isActive = data['isActive'] ?? false;
    final hasError = data['status']?['hasError'] ?? false;

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
