import 'package:eco_gestion/widgets/consumption_chart.dart';
import 'package:flutter/material.dart';
import 'package:eco_gestion/services/firebase_service.dart';
import 'package:eco_gestion/config/routes.dart';

class TenantDashboard extends StatefulWidget {
  const TenantDashboard({super.key});

  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedIndex = 0;
  bool _isLoading = false; // Ajout de la variable manquante

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Méthode pour charger les données
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Rechargez vos données ici
      // Par exemple :
      // await _firebaseService.getRentals();
      // await _firebaseService.getPayments();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              final BuildContext currentContext = context;
              final bool? confirm = await showDialog<bool>(
                context: currentContext,
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
                  Navigator.pushReplacementNamed(currentContext, AppRoutes.login);
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
    );
  }

  Widget _buildBody() {
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
    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.green,
      child: Stack(
        children: [
          const SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bienvenue sur EcoGestion',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Votre consommation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '250 kWh',
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
                  'Conseils d\'économie',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                // Placeholder pour les conseils
                Card(
                  color: Colors.lightBlue,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Utilisez des ampoules LED pour réduire votre consommation',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Colors.green)),
        ],
      ),
    );
  }

  Widget _buildConsumptionTab() {
    // Données fictives pour la consommation mensuelle
    final List<double> monthlyData = [
      120, 140, 160, 180, 200, 220, 
      250, 230, 210, 190, 170, 150
    ];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ma consommation',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Graphique de consommation mensuelle
          ConsumptionChart(
            monthlyData: monthlyData,
            title: 'Consommation mensuelle',
            barColor: Colors.green,
          ),
          
          const SizedBox(height: 24),
          
          // Statistiques de consommation
          const Text(
            'Statistiques',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // Cartes de statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Moyenne', 
                  '195 kWh', 
                  Icons.show_chart,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Maximum', 
                  '250 kWh', 
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
                  '120 kWh', 
                  Icons.arrow_downward,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total annuel', 
                  '2320 kWh', 
                  Icons.calendar_today,
                  Colors.purple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Supprimez la méthode _buildEnergyTypeRow qui n'est pas utilisée
  
  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: 12, 
      itemBuilder: (context, index) {
        // Calcul du mois (mois actuel - index)
        final now = DateTime.now();
        final month = DateTime(now.year, now.month - index);
        final monthName = _getMonthName(month.month);

        // Valeur aléatoire pour la démonstration
        final value = 200 + (index * 10) + (index % 3 == 0 ? 50 : 0);

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
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
                    Icons.calendar_month,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$monthName ${month.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Consommation: $value kWh',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
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
      'Décembre',
    ];
    return monthNames[month - 1];
  }

  Widget _buildTipsTab() {
    final tips = [
      {
        'title': 'Utilisez des ampoules LED',
        'description':
            'Les ampoules LED consomment jusqu\'à 80% moins d\'énergie que les ampoules traditionnelles et durent plus longtemps.',
        'icon': Icons.lightbulb,
        'color': Colors.amber,
      },
      {
        'title': 'Éteignez les appareils en veille',
        'description':
            'Les appareils en mode veille peuvent représenter jusqu\'à 10% de votre facture d\'électricité.',
        'icon': Icons.power_settings_new,
        'color': Colors.red,
      },
      {
        'title': 'Optimisez votre chauffage',
        'description':
            'Baisser la température de 1°C peut réduire votre consommation de chauffage de 7%.',
        'icon': Icons.thermostat,
        'color': Colors.orange,
      },
      {
        'title': 'Utilisez des multiprises avec interrupteur',
        'description':
            'Cela vous permet de couper complètement l\'alimentation de plusieurs appareils en même temps.',
        'icon': Icons.electrical_services,
        'color': Colors.blue,
      },
      {
        'title': 'Lavez votre linge à basse température',
        'description':
            'Laver à 30°C au lieu de 60°C consomme 3 fois moins d\'énergie.',
        'icon': Icons.local_laundry_service,
        'color': Colors.indigo,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: tips.length,
      itemBuilder: (context, index) {
        final tip = tips[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: (tip['color'] as Color).withOpacity(0.2),
              child: Icon(
                tip['icon'] as IconData,
                color: tip['color'] as Color,
              ),
            ),
            title: Text(
              tip['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(tip['description'] as String),
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  bottom: 16.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.bookmark_border),
                      label: const Text('Sauvegarder'),
                      onPressed: () {
                        // TODO: Sauvegarder le conseil
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.share),
                      label: const Text('Partager'),
                      onPressed: () {
                        // TODO: Partager le conseil
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
