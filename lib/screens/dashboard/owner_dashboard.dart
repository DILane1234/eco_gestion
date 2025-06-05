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
    _simulatorService.startSimulation(SIMULATED_METER_ID);
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

  // Déplacez la méthode _loadData() à l'intérieur de la classe
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Rechargez vos données ici
      // Par exemple :
      // await _firebaseService.getProperties();
      // await _firebaseService.getNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'actualisation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildPropertiesTab();
      case 2:
        return _buildTenantsTab();
      case 3:
        return _buildStatsTab();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tableau de bord',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Ajouter le widget d'affichage du compteur
            MeterDisplay(meterId: SIMULATED_METER_ID),

            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consommation totale',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1250 kWh',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Ce mois-ci'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Alertes récentes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            // Placeholder pour les alertes
            Card(
              color: Colors.amber,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.warning),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Consommation anormale dans Appartement 3'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPropertiesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount:
          3, // Nombre de propriétés (à remplacer par des données réelles)
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          elevation: 2,
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(Icons.home_work, color: Colors.green.shade700),
            ),
            title: Text(
              'Propriété ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Adresse: 123 Rue de l\'Exemple, Ville ${index + 1}'),
                const SizedBox(height: 4),
                Text('Nombre d\'unités: ${(index + 1) * 2}'),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.electric_meter,
                      size: 16,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Consommation: ${(index + 1) * 500} kWh',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: () {
                // Navigation vers les détails de la propriété
                // TODO: Implémenter la navigation
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTenantsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount:
          5, // Nombre de locataires (à remplacer par des données réelles)
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
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
            title: Text('Locataire ${index + 1}'),
            subtitle: Text('Appartement ${index + 1}'),
            trailing: SizedBox(
              width: 96, // Fixed width to accommodate two icons
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Statistiques de consommation',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    child: ConsumptionChart(
                      monthlyData: monthlyData,
                      title: 'Consommation mensuelle',
                      barColor: Colors.green,
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Affichage des statistiques
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

              // Bouton du compteur intelligent
              SizedBox(
                width: double.infinity,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SmartMeterDetail(
                            meterId: 'compteur1',
                            isOwner: true,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
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
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compteur Intelligent',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Consulter les données en temps réel',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
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

// Supprimez la méthode _loadData() qui est définie ici à l'extérieur de la classe
