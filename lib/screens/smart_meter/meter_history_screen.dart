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
    print('Initialisation de MeterHistoryScreen');
    print('ID du compteur: ${widget.meterId}');
    _loadHistoryData();
  }

  Future<void> _loadHistoryData() async {
    print('Début du chargement des données historiques...');
    print('ID du compteur dans _loadHistoryData: ${widget.meterId}');

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
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

      print('Période sélectionnée: $_selectedPeriod');
      print('Date de début: $startDate');
      print('Date de fin: $endDate');

      // Convertir les dates en timestamps pour la requête
      final startTimestamp = startDate.millisecondsSinceEpoch;
      final endTimestamp = endDate.millisecondsSinceEpoch;

      print('Recherche des données pour le compteur: ${widget.meterId}');

      // Générer des données de test immédiatement
      print('Génération des données de test...');
      final testData = _generateTestData(startTimestamp, endTimestamp);
      print('Données de test générées: ${testData['power']!.length} points');

      if (!mounted) return;

      setState(() {
        _powerData = testData['power']!;
        _energyData = testData['energy']!;
        _isLoading = false;
      });
      print('État mis à jour avec les données de test');

      // Sauvegarder les données de test en arrière-plan
      try {
        await _saveTestData(testData);
        print('Données de test sauvegardées');
      } catch (e) {
        print('Erreur lors de la sauvegarde des données de test: $e');
        // Ne pas afficher d'erreur à l'utilisateur car les données sont déjà affichées
      }
    } catch (e) {
      print('Erreur lors du chargement des données historiques: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _powerData = [];
        _energyData = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des données: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Réessayer',
            onPressed: () => _loadHistoryData(),
          ),
        ),
      );
    }
  }

  // Générer des données de test
  Map<String, List<FlSpot>> _generateTestData(
      int startTimestamp, int endTimestamp) {
    List<FlSpot> powerSpots = [];
    List<FlSpot> energySpots = [];

    final duration = endTimestamp - startTimestamp;
    final interval = (duration / 24).round(); // 24 points de données

    for (int i = 0; i < 24; i++) {
      final timestamp = startTimestamp + (interval * i);
      final normalizedX = _normalizeTimestamp(
        timestamp,
        startTimestamp,
        endTimestamp,
      );

      // Générer des valeurs aléatoires réalistes
      final power = 100 + (i % 3) * 50.0; // Entre 100W et 250W
      final energy = (power * 0.1) + (i * 0.5); // Accumulation d'énergie

      powerSpots.add(FlSpot(normalizedX, power));
      energySpots.add(FlSpot(normalizedX, energy));
    }

    return {
      'power': powerSpots,
      'energy': energySpots,
    };
  }

  // Sauvegarder les données de test
  Future<void> _saveTestData(Map<String, List<FlSpot>> testData) async {
    try {
      final batch = _historyRef.child(widget.meterId);
      final now = DateTime.now().millisecondsSinceEpoch;

      for (int i = 0; i < testData['power']!.length; i++) {
        final powerSpot = testData['power']![i];
        final energySpot = testData['energy']![i];

        await batch.push().set({
          'timestamp': now -
              (24 - i) * 3600000, // Une heure en arrière pour chaque point
          'power': powerSpot.y,
          'energy': energySpot.y,
        });
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde des données de test: $e');
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

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Historique du compteur'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) {
                setState(() {
                  _selectedPeriod = value;
                });
                _loadHistoryData();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'day', child: Text('Jour')),
                const PopupMenuItem(value: 'week', child: Text('Semaine')),
                const PopupMenuItem(value: 'month', child: Text('Mois')),
              ],
            ),
          ],
        ),
        body: _isLoading
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
                    final startDate = _selectedPeriod == 'day'
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
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d), width: 1),
          ),
          minX: 0,
          maxX: 10,
          minY: 0,
          maxY: spots.isEmpty
              ? 10
              : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: color.withAlpha(26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
