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

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Vérifier d'abord l'état de l'authentification
      final authState = await _firebaseService.checkAuthState();
      if (!authState['isAuthenticated']) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      // Vérifier le type d'utilisateur
      final userType = authState['userType'] as String?;
      if (userType != 'tenant') {
        print('Type d\'utilisateur invalide: $userType');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      // Tester la connexion à Firebase avec un timeout
      final isConnected = await _firebaseService.testDatabaseConnection();
      if (!isConnected) {
        throw Exception(
            'Impossible de se connecter à Firebase. Veuillez vérifier votre connexion internet.');
      }

      // Initialiser les données de consommation si nécessaire
      await _firebaseService.initializeConsumptionData();

      // Charger les données de consommation
      final consumptionData = await _firebaseService.getConsumptionData(false);
      print('Données de consommation chargées: $consumptionData');

      // Charger les données du compteur simulé
      final meterRef = FirebaseDatabase.instance
          .ref()
          .child('compteurs')
          .child(SIMULATED_METER_ID);
      final meterData = await meterRef.get();
      final smartMeterData =
          Map<String, dynamic>.from(meterData.value as Map? ?? {});

      if (!mounted) return;
      setState(() {
        _consumptionData = consumptionData;
        _smartMeterData = smartMeterData;
        _isLoading = false;
      });

      // Configurer l'écoute des mises à jour du compteur
      meterRef.onValue.listen((event) {
        if (event.snapshot.value != null && mounted) {
          setState(() {
            _smartMeterData =
                Map<String, dynamic>.from(event.snapshot.value as Map);
          });
        }
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      // Afficher un message d'erreur plus explicite
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Réessayer',
            textColor: Colors.white,
            onPressed: () {
              _loadData();
            },
          ),
        ),
      );
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
              icon: const Icon(Icons.account_balance_wallet),
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.tenantPrepaid);
              },
              tooltip: 'Gestion Prépayée',
            ),
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
              currentPower.toStringAsFixed(1),
              'W',
              Icons.electric_bolt,
              Colors.blue,
              subtitle: 'Puissance instantanée',
              isPowerCard: true,
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
              estimatedCost.toStringAsFixed(1),
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
      {String? subtitle, Widget? chart, bool isPowerCard = false}) {
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
                  fontSize: isPowerCard ? 20 : 28,
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
                    fontSize: isPowerCard ? 12 : 14,
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

    // Liste des valeurs mensuelles dans l'ordre
    final List<double> monthlyValues = [
      monthlyData['January'] ?? 0.0,
      monthlyData['February'] ?? 0.0,
      monthlyData['March'] ?? 0.0,
      monthlyData['April'] ?? 0.0,
      monthlyData['May'] ?? 0.0,
      monthlyData['June'] ?? 0.0,
      monthlyData['July'] ?? 0.0,
      monthlyData['August'] ?? 0.0,
      monthlyData['September'] ?? 0.0,
      monthlyData['October'] ?? 0.0,
      monthlyData['November'] ?? 0.0,
      monthlyData['December'] ?? 0.0,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Graphique de consommation
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Consommation Mensuelle(kWh)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total: ${statistics['annual_total']?.toStringAsFixed(1) ?? 0} kWh',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final screenHeight = MediaQuery.of(context).size.height;
                    final maxHeight = screenHeight * 0.4;
                    final minHeight = 250.0;
                    final height = constraints.maxWidth * 0.6;

                    return ClipRect(
                      child: SizedBox(
                        width: constraints.maxWidth,
                        height: height.clamp(minHeight, maxHeight),
                        child: ConsumptionChart(
                          monthlyData: monthlyValues,
                          title: '',
                          barColor: Colors.green,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Détails du compteur
        StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance
              .ref('compteurs/compteur_simule_1')
              .onValue,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Erreur: ${snapshot.error}'));
            }

            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator());
            }

            final rawData = snapshot.data!.snapshot.value;
            final meterData = rawData is Map
                ? Map<String, dynamic>.from(rawData as Map)
                : <String, dynamic>{};

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Détails du Compteur',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => SmartMeterDetail(
                              meterId: 'compteur_simule_1',
                              isOwner: false,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.electric_meter,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Compteur Simulé',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color:
                                              (meterData['is_active'] ?? false)
                                                  ? Colors.green.shade500
                                                  : Colors.red.shade500,
                                          size: 8,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (meterData['is_active'] ?? false)
                                              ? 'En ligne'
                                              : 'Hors ligne',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: (meterData['is_active'] ??
                                                    false)
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (meterData['last_reading'] != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Dernière mise à jour: ${DateTime.fromMillisecondsSinceEpoch(meterData['last_reading']['timestamp'] ?? 0).toString().substring(0, 16)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        // Statistiques générales
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistiques Générales',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.2,
                  children: [
                    _buildStatCard(
                      'Consommation Moyenne',
                      '${statistics['average']?.toStringAsFixed(1) ?? 0} kWh',
                      Icons.analytics,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      'Consommation Totale',
                      '${statistics['annual_total']?.toStringAsFixed(1) ?? 0} kWh',
                      Icons.summarize,
                      Colors.green,
                    ),
                    _buildStatCard(
                      'Consommation Maximale',
                      '${statistics['maximum']?.toStringAsFixed(1) ?? 0} kWh',
                      Icons.trending_up,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      'Consommation Minimale',
                      '${statistics['minimum']?.toStringAsFixed(1) ?? 0} kWh',
                      Icons.trending_down,
                      Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.green.shade700,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
