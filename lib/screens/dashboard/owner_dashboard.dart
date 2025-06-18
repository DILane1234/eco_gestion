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
  bool _isLoading = false;
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
      print('Début du chargement des données...');

      // Vérifier l'état de l'authentification
      final authState = await _firebaseService.checkAuthState();
      print('État d\'authentification: $authState');

      if (!authState['isAuthenticated']) {
        print('Utilisateur non authentifié');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      // Vérifier le type d'utilisateur
      final userType = authState['userType'] as String?;
      if (userType != 'owner') {
        print('Type d\'utilisateur invalide: $userType');
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, AppRoutes.login);
        return;
      }

      // Initialiser les données de consommation
      print('Initialisation des données de consommation...');
      await _firebaseService.initializeConsumptionData();
      print('Données de consommation initialisées');

      // Tester la connexion à Firebase
      print('Test de connexion à Firebase...');
      final isConnected = await _firebaseService.testDatabaseConnection();
      if (!isConnected) {
        throw Exception(
            'Impossible de se connecter à Firebase. Veuillez vérifier votre connexion internet.');
      }
      print('Connexion à Firebase réussie');

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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement des données...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomeTab(),
          _buildTenantsTab(),
          _buildStatsTab(),
        ],
      ),
    );
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

                if (confirm == true) {
                  await _firebaseService.signOut();
                  if (mounted) {
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
      future: _firebaseService.getConsumptionData(true),
      builder: (context, consumptionSnapshot) {
        if (consumptionSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (consumptionSnapshot.hasError) {
          return Center(child: Text('Erreur: ${consumptionSnapshot.error}'));
        }

        final consumptionData = consumptionSnapshot.data ?? {};

        // Conversion sécurisée des données mensuelles
        Map<String, dynamic> monthlyData = {};
        if (consumptionData['monthly_consumption'] != null) {
          final rawData = consumptionData['monthly_consumption'];
          if (rawData is Map) {
            rawData.forEach((key, value) {
              if (key is String && value is num) {
                monthlyData[key] = value.toDouble();
              }
            });
          }
        }

        // Conversion sécurisée des statistiques
        Map<String, dynamic> statistics = {};
        if (consumptionData['statistics'] != null) {
          final rawStats = consumptionData['statistics'];
          if (rawStats is Map) {
            rawStats.forEach((key, value) {
              if (key is String && value is num) {
                statistics[key] = value.toDouble();
              }
            });
          }
        }

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
            const Text(
              'Statistiques de Consommation',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

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

            // Détails du compteur
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance
                  .ref('compteurs/compteur_simule_1')
                  .onValue,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur: ${snapshot.error}'));
                }

                if (!snapshot.hasData ||
                    snapshot.data!.snapshot.value == null) {
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
                                  isOwner: true,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                              color: (meterData['is_active'] ??
                                                      false)
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
                                                color:
                                                    (meterData['is_active'] ??
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
          ],
        );
      },
    );
  }

  Widget _buildDataTile(
      String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '$value $unit',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
      ),
    );
  }
}
