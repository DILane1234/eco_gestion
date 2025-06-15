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
        await _authService.assignMeterToTenant(user.uid, 'compteur_simule_1');
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
        setState(() {
          _isLoading = false;
        });
        return {};
      }

      // Récupérer les données utilisateur depuis Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data() ?? {};
      print('Données utilisateur Firestore: $userData');

      // Récupérer le meterId depuis les données utilisateur
      final meterId = userData['meterId'] ?? 'compteur_simule_1';
      print('MeterId trouvé: $meterId');

      // Récupérer les données du compteur depuis la Realtime Database
      final meterSnapshot =
          await FirebaseDatabase.instance.ref('compteurs/$meterId').get();
      final meterData = meterSnapshot.value as Map<dynamic, dynamic>? ?? {};
      print('Données du compteur: $meterData');

      final data = {
        'compteurs': {
          meterId: meterData,
        },
      };

      setState(() {
        _consumptionData = data;
        _isLoading = false;
      });

      return data;
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
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

    if (_consumptionData.isEmpty) {
      return const Center(
        child: Text('Aucune donnée disponible'),
      );
    }

    final compteurs = _consumptionData['compteurs'] as Map? ?? {};
    final meterId = compteurs.keys.first;
    final meterData = compteurs[meterId] as Map<dynamic, dynamic>? ?? {};

    final todayConsumption = meterData['power'] != null
        ? (meterData['power'] as num).toDouble()
        : 0.0;
    final monthlyConsumption = meterData['energy'] != null
        ? (meterData['energy'] as num).toDouble()
        : 0.0;
    final averageConsumption = monthlyConsumption / 30; // Moyenne journalière
    final estimatedCost = (monthlyConsumption * 30).round(); // 30 FCFA par kWh

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec message personnalisé
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
                    'Bonjour ${meterData['name'] ?? 'Utilisateur'} 👋',
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

            // Cartes de consommation
            _buildConsumptionCard(
              'Consommation du jour',
              todayConsumption.toStringAsFixed(1),
              'W',
              Icons.today,
              Colors.blue,
              subtitle: 'Puissance actuelle',
              chart: _buildDailyConsumptionChart(meterData),
            ),
            const SizedBox(height: 16),
            _buildConsumptionCard(
              'Consommation mensuelle',
              monthlyConsumption.toStringAsFixed(1),
              'kWh',
              Icons.calendar_month,
              Colors.green,
              subtitle: 'Énergie totale',
              chart: _buildMonthlyConsumptionChart(meterData),
            ),
            const SizedBox(height: 16),
            _buildConsumptionCard(
              'Consommation moyenne',
              averageConsumption.toStringAsFixed(1),
              'kWh',
              Icons.analytics,
              Colors.orange,
              subtitle: 'Par jour',
            ),
            const SizedBox(height: 16),
            _buildConsumptionCard(
              'Coût estimé',
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

  Widget _buildDailyConsumptionChart(Map<dynamic, dynamic> meterData) {
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
                FlSpot(0, meterData['power'] ?? 0),
                FlSpot(6, meterData['power'] ?? 0),
                FlSpot(12, meterData['power'] ?? 0),
                FlSpot(18, meterData['power'] ?? 0),
                FlSpot(24, meterData['power'] ?? 0),
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

  Widget _buildMonthlyConsumptionChart(Map<dynamic, dynamic> meterData) {
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
                FlSpot(0, meterData['energy'] ?? 0),
                FlSpot(7, meterData['energy'] ?? 0),
                FlSpot(14, meterData['energy'] ?? 0),
                FlSpot(21, meterData['energy'] ?? 0),
                FlSpot(30, meterData['energy'] ?? 0),
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_consumptionData.isEmpty) {
      return const Center(
        child: Text('Aucune donnée disponible'),
      );
    }

    final compteurs = _consumptionData['compteurs'] as Map? ?? {};
    print('Compteurs: $compteurs');

    if (compteurs.isEmpty) {
      return Card(
        elevation: 4,
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.electric_meter,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'Aucun compteur assigné',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Veuillez contacter votre propriétaire pour vous assigner un compteur.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Pour un locataire, on ne prend que le premier compteur assigné
    final meterId = compteurs.keys.first;
    print('MeterId sélectionné: $meterId');
    final meterData = compteurs[meterId] as Map<dynamic, dynamic>? ?? {};

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mon Compteur Intelligent',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.electric_meter,
                color:
                    meterData['isActive'] == true ? Colors.green : Colors.grey,
              ),
              title: Text('Compteur $meterId'),
              subtitle: Text(
                meterData['isActive'] == true ? 'En ligne' : 'Hors ligne',
                style: TextStyle(
                  color: meterData['isActive'] == true
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
              trailing: Text(
                '${(meterData['power'] ?? 0).toStringAsFixed(2)} W',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SmartMeterDetail(
                      meterId: meterId,
                      isOwner: false,
                    ),
                  ),
                );
              },
              child: const Text('Voir les détails'),
            ),
          ],
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
