import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class MeterHistoryScreen extends StatefulWidget {
  final String meterId;

  const MeterHistoryScreen({super.key, required this.meterId});

  @override
  State<MeterHistoryScreen> createState() => _MeterHistoryScreenState();
}

class _MeterHistoryScreenState extends State<MeterHistoryScreen> {
  final DatabaseReference _historyRef = FirebaseDatabase.instance.ref(
    'history',
  );
  List<FlSpot> _powerData = [];
  List<FlSpot> _energyData = [];
  String _selectedPeriod = 'day'; // 'day', 'week', 'month'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    setState(() {
      _isLoading = true;
    });

    // Déterminer la plage de dates en fonction de la période sélectionnée
    DateTime endDate = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'day':
        startDate = endDate.subtract(const Duration(days: 1));
        break;
      case 'week':
        startDate = endDate.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = DateTime(endDate.year, endDate.month - 1, endDate.day);
        break;
      default:
        startDate = endDate.subtract(const Duration(days: 1));
    }

    // Convertir les dates en timestamps pour la requête
    final startTimestamp = startDate.millisecondsSinceEpoch;
    final endTimestamp = endDate.millisecondsSinceEpoch;

    try {
      final snapshot =
          await _historyRef
              .child(widget.meterId)
              .orderByChild('timestamp')
              .startAt(startTimestamp)
              .endAt(endTimestamp)
              .get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> rawData;

        // Correction de la conversion des données
        if (snapshot.value is Map) {
          rawData = snapshot.value as Map<dynamic, dynamic>;

          List<FlSpot> powerSpots = [];
          List<FlSpot> energySpots = [];

          rawData.forEach((key, value) {
            if (value is Map) {
              final timestamp =
                  value['timestamp'] is int
                      ? value['timestamp'] as int
                      : int.tryParse(value['timestamp'].toString()) ?? 0;

              final power =
                  value['power'] is num
                      ? (value['power'] as num).toDouble()
                      : double.tryParse(value['power'].toString()) ?? 0.0;

              final energy =
                  value['energy'] is num
                      ? (value['energy'] as num).toDouble()
                      : double.tryParse(value['energy'].toString()) ?? 0.0;

              // Normaliser le timestamp pour l'affichage sur le graphique
              final normalizedX = _normalizeTimestamp(
                timestamp,
                startTimestamp,
                endTimestamp,
              );

              powerSpots.add(FlSpot(normalizedX, power));
              energySpots.add(FlSpot(normalizedX, energy));
            }
          });

          // Trier les points par ordre chronologique
          powerSpots.sort((a, b) => a.x.compareTo(b.x));
          energySpots.sort((a, b) => a.x.compareTo(b.x));

          setState(() {
            _powerData = powerSpots;
            _energyData = energySpots;
            _isLoading = false;
          });
        } else {
          setState(() {
            _powerData = [];
            _energyData = [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _powerData = [];
          _energyData = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Erreur lors du chargement des données historiques: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Normalise le timestamp entre 0 et 10 pour l'affichage sur le graphique
  double _normalizeTimestamp(
    int timestamp,
    int startTimestamp,
    int endTimestamp,
  ) {
    final range = endTimestamp - startTimestamp;
    if (range <= 0) return 0.0; // Éviter la division par zéro

    final position = timestamp - startTimestamp;
    return (position / range) * 10;
  }

  // Convertit la valeur X normalisée en date lisible
  String _getDateFromX(double x, int startTimestamp, int endTimestamp) {
    try {
      final range = endTimestamp - startTimestamp;
      if (range <= 0) return "--:--"; // Éviter la division par zéro

      final timestamp = (x / 10 * range) + startTimestamp;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());

      switch (_selectedPeriod) {
        case 'day':
          return DateFormat('HH:mm').format(date);
        case 'week':
          return DateFormat('E').format(date); // Jour de la semaine
        case 'month':
          return DateFormat('dd/MM').format(date);
        default:
          return DateFormat('HH:mm').format(date);
      }
    } catch (e) {
      print('Erreur lors de la conversion de la date: $e');
      return "--:--";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique du compteur'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedPeriod = value;
              });
              _loadHistoryData();
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'day', child: Text('Jour')),
                  const PopupMenuItem(value: 'week', child: Text('Semaine')),
                  const PopupMenuItem(value: 'month', child: Text('Mois')),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Période: ${_getPeriodLabel()}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Puissance (W)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildChart(_powerData, Colors.blue),
                    const SizedBox(height: 24),
                    const Text(
                      'Énergie (kWh)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildChart(_energyData, Colors.green),
                  ],
                ),
              ),
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 'day':
        return 'Dernières 24 heures';
      case 'week':
        return 'Dernière semaine';
      case 'month':
        return 'Dernier mois';
      default:
        return 'Dernières 24 heures';
    }
  }

  Widget _buildChart(List<FlSpot> spots, Color color) {
    if (spots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Aucune donnée disponible pour cette période'),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  if (value % 2 == 0) {
                    final endDate = DateTime.now();
                    final startDate =
                        _selectedPeriod == 'day'
                            ? endDate.subtract(const Duration(days: 1))
                            : _selectedPeriod == 'week'
                            ? endDate.subtract(const Duration(days: 7))
                            : DateTime(
                              endDate.year,
                              endDate.month - 1,
                              endDate.day,
                            );

                    final startTimestamp = startDate.millisecondsSinceEpoch;
                    final endTimestamp = endDate.millisecondsSinceEpoch;

                    return Text(
                      _getDateFromX(value, startTimestamp, endTimestamp),
                      style: const TextStyle(fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withOpacity(0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
