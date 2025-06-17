import 'package:eco_gestion/screens/smart_meter/smart_meter_detail.dart';
import 'package:eco_gestion/widgets/consumption_chart.dart';
import 'package:flutter/material.dart';
import 'package:eco_gestion/services/firebase_service.dart';
import 'package:eco_gestion/config/routes.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eco_gestion/services/auth_service.dart';

class TenantDashboard extends StatefulWidget {
  const TenantDashboard({super.key});

  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;
  bool _isLoading = true;
  DateTime? _lastBackPressTime;
  bool _isExiting = false;
  Map<String, dynamic> _consumptionData = {};
  Map<String, dynamic> _smartMeterData = {};
  static const String SIMULATED_METER_ID = 'compteur_simule_1';

  @override
  void initState() {
    super.initState();
    _assignSimulatedMeter();
    _loadData();
  }

  Future<void> _assignSimulatedMeter() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _authService.assignMeterToTenant(user.uid, SIMULATED_METER_ID);
        print('Compteur simulé assigné avec succès');
      }
    } catch (e) {
      print('Erreur lors de l\'assignation du compteur simulé: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<Map<String, dynamic>> _loadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('Aucun utilisateur connecté');
        setState(() {
          _isLoading = false;
        });
        return {};
      }

      // Attendre que le token soit rafraîchi
      final token = await user.getIdToken(true);
      print('Token rafraîchi pour l\'utilisateur: ${user.uid}');

      // Récupérer les données utilisateur depuis Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      print('Données utilisateur Firestore: $userData');

      // Récupérer les données du compteur de consommation de l'utilisateur (mensuelle, statistiques)
      final databaseRef = FirebaseDatabase.instance.ref();
      final consumptionRef =
          databaseRef.child('users/${user.uid}/consumption/tenant');

      try {
        final consumptionSnapshot = await consumptionRef.get();

        if (!consumptionSnapshot.exists) {
          print(
              'Aucune donnée de consommation trouvée pour l\'utilisateur, initialisation...');
          await consumptionRef.set({
            'monthly_consumption': {
              'January': 120,
              'February': 140,
              'March': 160,
              'April': 180,
              'May': 200,
              'June': 220,
              'July': 250,
              'August': 230,
              'September': 210,
              'October': 190,
              'November': 170,
              'December': 150
            },
            'statistics': {
              'average': 195,
              'maximum': 250,
              'minimum': 120,
              'annual_total': 2320
            }
          });
        }

        // Récupérer les données de consommation mises à jour
        final updatedConsumptionSnapshot = await consumptionRef.get();
        final rawConsumptionData = updatedConsumptionSnapshot.value;
        final Map<String, dynamic> loadedConsumptionData = {};
        if (rawConsumptionData is Map) {
          rawConsumptionData.forEach((key, value) {
            if (key is String) {
              loadedConsumptionData[key] = value;
            }
          });
        }

        // Récupérer les données du compteur intelligent depuis le chemin global
        final smartMeterGlobalRef =
            databaseRef.child('compteurs/${SIMULATED_METER_ID}');
        final smartMeterSnapshot = await smartMeterGlobalRef.get();
        final Map<String, dynamic> loadedSmartMeterData = {};
        if (smartMeterSnapshot.exists && smartMeterSnapshot.value is Map) {
          (smartMeterSnapshot.value as Map).forEach((key, value) {
            if (key is String) {
              loadedSmartMeterData[key] = value;
            }
          });
        } else {
          print(
              'Aucune donnée trouvée pour le compteur intelligent global: ${SIMULATED_METER_ID}');
          // Optionnel: Initialiser des données par défaut pour le compteur global si non présent
          // Cela devrait être géré par MeterSimulatorService, mais peut être un fallback ici.
          // await smartMeterGlobalRef.set({...});
        }

        setState(() {
          _consumptionData =
              loadedConsumptionData; // Données de consommation utilisateur
          _smartMeterData =
              loadedSmartMeterData; // Données du compteur intelligent global
          _isLoading = false;
        });

        return loadedConsumptionData; // Retourne les données de consommation de l'utilisateur
      } catch (e) {
        print(
            'Erreur lors de l\'accès à la base de données (TenantDashboard): $e');
        setState(() {
          _isLoading = false;
        });
        return {};
      }
    } catch (e) {
      print(
          'Erreur lors du chargement général des données (TenantDashboard): $e');
      setState(() {
        _isLoading = false;
      });
      return {};
    }
  }

  Future<void> _exitApp() async {
    if (!_isExiting) {
      _isExiting = true;
      // Ferme l'application et nettoie la pile de navigation
      SystemChannels.platform.invokeMethod(
          'SystemNavigator.pop'); // Ferme proprement l'application
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // ignore: deprecated_member_use
      onPopInvoked: (didPop) {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appuyez à nouveau pour quitter'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          _exitApp();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Tableau de bord'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.profile);
              },
              tooltip: 'Mon Profil',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.settings);
              },
              tooltip: 'Paramètres',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                if (!mounted) return;
                final navigator = Navigator.of(context);

                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Déconnexion'),
                      content: const Text(
                        'Êtes-vous sûr de vouloir vous déconnecter ?',
                      ),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Déconnexion'),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true && mounted) {
                  await _firebaseService.signOut();
                  if (mounted) {
                    navigator.pushReplacementNamed(AppRoutes.login);
                  }
                }
              },
              tooltip: 'Déconnexion',
            ),
          ],
        ),
        body: _buildBody(),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
            BottomNavigationBarItem(
              icon: Icon(Icons.electric_meter),
              label: 'Consommation',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'Historique',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tips_and_updates),
              label: 'Conseils',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.green,
          unselectedItemColor: Colors.grey,
          onTap: _onItemTapped,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      );
    }

    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildConsumptionTab();
      case 2:
        return _buildHistoryTab();
      case 3:
        return _buildTipsTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_consumptionData.isEmpty && _smartMeterData.isEmpty) {
      return const Center(
        child: Text('Aucune donnée disponible'),
      );
    }

    // Données de consommation utilisateur (depuis _consumptionData)
    final monthlyConsumption = _consumptionData['statistics']?['average'] ?? 0;
    final averageConsumption = monthlyConsumption / 30;
    final estimatedCost = (monthlyConsumption * 30).round();

    // Données du compteur intelligent (depuis _smartMeterData)
    final currentPower = _smartMeterData['current_power'] ?? 0;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blue.shade700,
                    const Color.fromARGB(255, 105, 147, 109)
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withAlpha(77),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour ${_consumptionData['name'] ?? 'Utilisateur'} 👋',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Voici votre consommation aujourd\'hui',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withAlpha(230),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildConsumptionCard(
              'Puissance Actuelle',
              currentPower.toString(),
              'W',
              Icons.electric_bolt,
              Colors.blue,
              subtitle: 'Puissance instantanée',
            ),
            const SizedBox(height: 16),
            _buildConsumptionCard(
              'Consommation Mensuelle',
              monthlyConsumption.toStringAsFixed(1),
              'kWh',
              Icons.calendar_month,
              Colors.green,
              subtitle: 'Moyenne mensuelle',
            ),
            const SizedBox(height: 16),
            _buildConsumptionCard(
              'Consommation Moyenne',
              averageConsumption.toStringAsFixed(1),
              'kWh',
              Icons.analytics,
              Colors.orange,
              subtitle: 'Par jour',
            ),
            const SizedBox(height: 16),
            _buildConsumptionCard(
              'Coût Estimé',
              estimatedCost.toString(),
              'FCFA',
              Icons.attach_money,
              Colors.purple,
              subtitle: 'Basé sur la consommation mensuelle',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsumptionCard(
      String title, String value, String unit, IconData icon, Color color,
      {String? subtitle, Widget? chart}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha(26),
            color.withAlpha(13),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (chart != null) ...[
            chart,
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyConsumptionChart(Map<dynamic, dynamic> smartMeterData) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}h',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(0, smartMeterData['power'] ?? 0),
                FlSpot(6, smartMeterData['power'] ?? 0),
                FlSpot(12, smartMeterData['power'] ?? 0),
                FlSpot(18, smartMeterData['power'] ?? 0),
                FlSpot(24, smartMeterData['power'] ?? 0),
              ],
              isCurved: true,
              color: Colors.green.shade600,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.shade600.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyConsumptionChart(Map<dynamic, dynamic> smartMeterData) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}j',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                FlSpot(0, smartMeterData['energy'] ?? 0),
                FlSpot(7, smartMeterData['energy'] ?? 0),
                FlSpot(14, smartMeterData['energy'] ?? 0),
                FlSpot(21, smartMeterData['energy'] ?? 0),
                FlSpot(30, smartMeterData['energy'] ?? 0),
              ],
              isCurved: true,
              color: Colors.green.shade400,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.green.shade400.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsumptionTab() {
    if (_consumptionData.isEmpty && _smartMeterData.isEmpty) {
      return const Center(
        child: Text('Aucune donnée disponible dans le tableau de bord'),
      );
    }

    // Données de consommation utilisateur (depuis _consumptionData)
    final monthlyData = _consumptionData['monthly_consumption'] as Map? ?? {};
    final statistics = _consumptionData['statistics'] as Map? ?? {};

    // Données du compteur intelligent (depuis _smartMeterData)
    final lastReading = _smartMeterData['last_reading'] as Map? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec statistiques globales
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Statistiques Annuelles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatisticItem(
                          'Total Annuel',
                          '${statistics['annual_total'] ?? 0}',
                          'kWh',
                          Icons.calendar_today,
                          Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: _buildStatisticItem(
                          'Maximum',
                          '${statistics['maximum'] ?? 0}',
                          'kWh',
                          Icons.arrow_upward,
                          Colors.red,
                        ),
                      ),
                      Expanded(
                        child: _buildStatisticItem(
                          'Minimum',
                          '${statistics['minimum'] ?? 0}',
                          'kWh',
                          Icons.arrow_downward,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Détails du compteur intelligent
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Détails du Compteur Intelligent',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'État',
                    _smartMeterData['is_active'] == true ? 'Actif' : 'Inactif',
                    _smartMeterData['is_active'] == true
                        ? Colors.green
                        : Colors.red,
                  ),
                  _buildDetailRow(
                    'Puissance Actuelle',
                    '${_smartMeterData['current_power'] ?? 0} W',
                    Colors.blue,
                  ),
                  _buildDetailRow(
                    'Dernière Lecture',
                    '${lastReading['value'] ?? 0} kWh',
                    Colors.orange,
                  ),
                  _buildDetailRow(
                    'Date de Lecture',
                    _formatTimestamp(lastReading['timestamp']),
                    Colors.purple,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Graphique de consommation mensuelle
          const Text(
            'Consommation Mensuelle',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildMonthlyConsumptionList(monthlyData),
        ],
      ),
    );
  }

  Widget _buildStatisticItem(
      String label, String value, String unit, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Non disponible';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  Widget _buildMonthlyConsumptionList(Map monthlyData) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: months.map((month) {
            final value = (monthlyData[month] ?? 0) as num;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      month,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: value / 300, // Normalisé sur 300 kWh
                      backgroundColor: Colors.grey[200],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${value.toStringAsFixed(1)} kWh',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _firebaseService.getStatistics(false),
      builder: (context, statsSnapshot) {
        if (statsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (statsSnapshot.hasError) {
          return Center(child: Text('Erreur: ${statsSnapshot.error}'));
        }

        final stats = statsSnapshot.data ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historique de consommation',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              FutureBuilder<List<double>>(
                future: _firebaseService.getMonthlyData(false),
                builder: (context, monthlySnapshot) {
                  if (monthlySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (monthlySnapshot.hasError) {
                    return Center(
                        child: Text('Erreur: ${monthlySnapshot.error}'));
                  }

                  final monthlyData = monthlySnapshot.data ?? [];

                  if (monthlyData.isEmpty) {
                    return const Center(
                        child: Text('Aucune donnée disponible'));
                  }

                  return SizedBox(
                    width: double.infinity,
                    height: 300,
                    child: ConsumptionChart(
                      monthlyData: monthlyData,
                      title: 'Consommation mensuelle',
                      barColor: Colors.green,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Détails mensuels',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final monthNames = [
                    'Janvier',
                    'Février',
                    'Mars',
                    'Avril',
                    'Mai',
                    'Juin',
                    'Juillet',
                    'Août',
                    'Septembre',
                    'Octobre',
                    'Novembre',
                    'Décembre'
                  ];
                  final month = monthNames[index];
                  final consumption =
                      stats['monthly_consumption']?[month] ?? 0.0;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.calendar_month,
                            color: Colors.green.shade700),
                      ),
                      title: Text(month),
                      subtitle: Text(
                          'Consommation: ${consumption.toStringAsFixed(1)} kWh'),
                      trailing: Icon(Icons.chevron_right,
                          color: Colors.grey.shade400),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTipsTab() {
    final tips = [
      {
        'title': 'Éclairage',
        'icon': Icons.lightbulb_outline,
        'tips': [
          'Éteignez les lumières en quittant une pièce',
          'Utilisez des ampoules LED basse consommation',
          'Profitez de la lumière naturelle pendant la journée'
        ]
      },
      {
        'title': 'Électroménager',
        'icon': Icons.tv,
        'tips': [
          'Débranchez les appareils en veille',
          'Utilisez le mode économie d\'énergie',
          'Entretenez régulièrement vos appareils'
        ]
      },
      {
        'title': 'Climatisation',
        'icon': Icons.ac_unit,
        'tips': [
          'Maintenez une température de 26°C',
          'Fermez les fenêtres pendant l\'utilisation',
          'Nettoyez régulièrement les filtres'
        ]
      },
      {
        'title': 'Cuisine',
        'icon': Icons.kitchen,
        'tips': [
          'Couvrez les casseroles pendant la cuisson',
          'Utilisez des casseroles adaptées à la taille des plaques',
          'Dégivrez régulièrement votre réfrigérateur'
        ]
      }
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conseils d\'économie d\'énergie',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Des astuces simples pour réduire votre consommation',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ...tips
              .map((category) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(category['icon'] as IconData,
                                color: Colors.green.shade700),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            category['title'] as String,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...(category['tips'] as List<String>).map((tip) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.check_circle_outline,
                                  color: Colors.green.shade600),
                              title: Text(tip),
                            ),
                          )),
                      const SizedBox(height: 24),
                    ],
                  ))
              .toList(),
        ],
      ),
    );
  }
}
