import 'package:eco_gestion/screens/smart_meter/smart_meter_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Importez le service Firebase
import 'package:eco_gestion/services/firebase_service.dart';
import 'package:eco_gestion/config/routes.dart';
// Au début du fichier, ajoutez l'import
import 'package:eco_gestion/widgets/consumption_chart.dart';
import 'package:eco_gestion/services/meter_simulator_service.dart';
import 'package:eco_gestion/widgets/meter_display.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eco_gestion/widgets/smart_meter_card.dart';

class OwnerDashboard extends StatefulWidget {
  const OwnerDashboard({super.key});

  @override
  State<OwnerDashboard> createState() => _OwnerDashboardState();
}

class _OwnerDashboardState extends State<OwnerDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  final MeterSimulatorService _simulatorService = MeterSimulatorService();
  int _selectedIndex = 0;
  bool _isLoading = false; // Ajout de la variable _isLoading
  DateTime? _lastBackPressTime;
  bool _isExiting = false;
  static const String SIMULATED_METER_ID = 'compteur_simule_1';

  @override
  void initState() {
    super.initState();
    // Démarrer la simulation
    _simulatorService.startSimulation();
    // Charger les données
    _loadData();
  }

  @override
  void dispose() {
    // Arrêter la simulation
    _simulatorService.stopSimulation();
    super.dispose();
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
      // Initialiser les données de consommation si nécessaire
      await _firebaseService.initializeConsumptionData();

      // Vérifier l'état de l'authentification
      final authState = await _firebaseService.checkAuthState();
      if (!authState['isAuthenticated']) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur lors du chargement des données: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de chargement: ${e.toString()}'),
          backgroundColor: Colors.red,
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
                // Stocker le contexte dans une variable locale n'est pas suffisant
                // car nous devons vérifier si le State est toujours monté
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

                // Si l'utilisateur confirme, se déconnecter
                if (confirm == true) {
                  await _firebaseService.signOut();
                  if (mounted) {
                    // Utiliser context directement après avoir vérifié mounted
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
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
              icon: Icon(Icons.business),
              label: 'Propriétés',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Locataires',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'Statistiques',
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

    return SafeArea(
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildPropertiesTab(),
          _buildTenantsTab(),
          _buildStatsTab(),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Tableau de bord',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        MeterDisplay(meterId: SIMULATED_METER_ID),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consommation totale',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Text(
                  '1250 kWh',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Text(
                  'Ce mois-ci',
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Alertes récentes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          color: Colors.amber,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.warning),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Consommation anormale dans Appartement 3',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPropertiesTab() {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance.ref('compteurs').onValue,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
                'Erreur de chargement des données des compteurs intelligents'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final data =
            Map<String, dynamic>.from(snapshot.data!.snapshot.value as Map);
        final meters = data.entries.map((entry) {
          return SmartMeterCard(
            meterId: entry.key,
            isOwner: true,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SmartMeterDetail(
                    meterId: entry.key,
                    isOwner: true,
                  ),
                ),
              );
            },
          );
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mes Compteurs Intelligents',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...meters,
          ],
        );
      },
    );
  }

  Widget _buildTenantsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.amber.shade100,
              child: Text(
                'L${index + 1}',
                style: TextStyle(
                  color: Colors.amber.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              'Locataire ${index + 1}',
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'Appartement ${index + 1}',
              overflow: TextOverflow.ellipsis,
            ),
            trailing: SizedBox(
              width: 96,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.message_outlined, size: 20),
                    padding: const EdgeInsets.all(8),
                    onPressed: () {
                      // TODO: Envoyer un message au locataire
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.info_outline, size: 20),
                    padding: const EdgeInsets.all(8),
                    onPressed: () {
                      // TODO: Afficher les détails du locataire
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _firebaseService.getStatistics(true),
      builder: (context, statsSnapshot) {
        if (statsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (statsSnapshot.hasError) {
          return Center(child: Text('Erreur: ${statsSnapshot.error}'));
        }

        final stats = statsSnapshot.data ?? {};

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Statistiques de consommation',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<double>>(
              future: _firebaseService.getMonthlyData(true),
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

                return SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRect(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        child: Container(
                          height: 320,
                          clipBehavior: Clip.hardEdge,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ConsumptionChart(
                            monthlyData: monthlyData,
                            title: 'Consommation mensuelle',
                            barColor: Colors.green,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Moyenne',
                    '${stats['average']} kWh',
                    Icons.show_chart,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Maximum',
                    '${stats['maximum']} kWh',
                    Icons.arrow_upward,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Minimum',
                    '${stats['minimum']} kWh',
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Total annuel',
                    '${stats['annual_total']} kWh',
                    Icons.calendar_today,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FutureBuilder<Map<String, dynamic>>(
              future: _firebaseService.getConsumptionData(true),
              builder: (context, consumptionSnapshot) {
                if (consumptionSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (consumptionSnapshot.hasError) {
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Erreur de chargement des données des compteurs intelligents',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final consumptionData = consumptionSnapshot.data ?? {};
                final smartMeters = consumptionData['compteurs'] as Map? ?? {};

                if (smartMeters.isEmpty) {
                  return Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'Aucun compteur intelligent disponible',
                              style: TextStyle(color: Colors.blue.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: smartMeters.length,
                  itemBuilder: (context, index) {
                    final meterId = smartMeters.keys.elementAt(index);
                    final meterData = smartMeters[meterId] as Map? ?? {};

                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => SmartMeterDetail(
                                meterId: meterId,
                                isOwner: true,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Compteur $meterId',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Consulter les données en temps réel',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.power,
                                          color: Colors.green.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Puissance actuelle',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${((meterData['current_power'] ?? 0) / 1000).toStringAsFixed(1)} kW',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: (meterData['is_active'] ??
                                                    false)
                                                ? Colors.green.shade50
                                                : Colors.red.shade50,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: (meterData['is_active'] ??
                                                      false)
                                                  ? Colors.green.shade200
                                                  : Colors.red.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.circle,
                                                color:
                                                    (meterData['is_active'] ??
                                                            false)
                                                        ? Colors.green.shade500
                                                        : Colors.red.shade500,
                                                size: 8,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                (meterData['is_active'] ??
                                                        false)
                                                    ? 'En ligne'
                                                    : 'Hors ligne',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      (meterData['is_active'] ??
                                                              false)
                                                          ? Colors
                                                              .green.shade700
                                                          : Colors.red.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (meterData['last_reading'] != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Dernière lecture: ${DateTime.fromMillisecondsSinceEpoch(meterData['last_reading']['timestamp'] ?? 0).toString().substring(0, 16)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // TODO: Implement the tap action
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
