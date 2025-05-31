import 'package:flutter/material.dart';
import 'package:eco_gestion/services/firebase_service.dart';
import 'package:eco_gestion/config/routes.dart';
import 'package:provider/provider.dart';
import 'package:eco_gestion/config/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String? _userName;
  String? _userEmail;
  String? _userType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Récupérer les informations de l'utilisateur
      final user = _firebaseService.currentUser;
      if (user != null) {
        _userEmail = user.email;
        
        // Récupérer les données supplémentaires depuis Firestore
        final userType = await _firebaseService.getUserType();
        _userType = userType == 'owner' ? 'Propriétaire' : 'Locataire';
        
        // Récupérer le nom de l'utilisateur
        _userName = await _firebaseService.getUserName();
      }
    } catch (e) {
      // Améliorer la gestion des erreurs
      print('Erreur lors du chargement des données utilisateur: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de charger les données: $e'),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Section profil
                const Text(
                  'Profil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: const Text('Email'),
                          subtitle: Text(_userEmail ?? 'Non disponible'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Nom'),
                          subtitle: Text(_userName ?? 'Non disponible'),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.person),
                          title: const Text('Type de compte'),
                          subtitle: Text(_userType ?? 'Non disponible'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section application
                const Text(
                  'Application',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.notifications),
                          title: const Text('Notifications'),
                          trailing: Switch(
                            value: true, // À remplacer par une valeur réelle
                            onChanged: (value) {
                              // Gérer le changement
                            },
                            activeColor: Colors.green,
                          ),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.dark_mode),
                          title: const Text('Mode sombre'),
                          trailing: Switch(
                            value: themeProvider.isDarkMode,
                            onChanged: (value) {
                              themeProvider.toggleTheme();
                            },
                            activeColor: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section compte
                const Text(
                  'Compte',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.password),
                          title: const Text('Changer le mot de passe'),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.pushNamed(context, AppRoutes.changePassword);
                          },
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text(
                            'Déconnexion',
                            style: TextStyle(color: Colors.red),
                          ),
                          onTap: () async {
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Déconnexion'),
                                  content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
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
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Version de l'application
                const Center(
                  child: Text(
                    'EcoGestion v1.0.0',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
    );
  }
}