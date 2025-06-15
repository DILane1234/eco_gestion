import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eco_gestion/services/firebase_service.dart';
import 'package:eco_gestion/config/routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum UserRole { owner, tenant }

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  UserRole _selectedRole = UserRole.tenant;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // Afficher des informations de débogage
        await _firebaseService.debugAuthentication();

        final email = _emailController.text.trim();
        final password = _passwordController.text;
        final name = _nameController.text.trim();
        final userType = _selectedRole == UserRole.owner ? 'owner' : 'tenant';

        print("Début de l'inscription...");
        print("Email: $email");
        print("Nom: $name");
        print("Type d'utilisateur: $userType");

        // Inscription
        final userCredential =
            await _firebaseService.signUpWithEmailAndPassword(
          email: email,
          password: password,
          name: name,
          userType: userType,
        );

        print("Inscription réussie. UID: ${userCredential.user?.uid}");

        // Vérification de l'authentification
        await _firebaseService.debugAuthentication();

        // Vérification du rôle stocké
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user?.uid ?? '')
            .get();

        final confirmedUserType = userDoc.data()?['userType'] as String?;
        print("Type d'utilisateur confirmé: $confirmedUserType");

        if (!mounted) return;

        if (confirmedUserType == 'owner') {
          print("Redirection vers le dashboard propriétaire");
          Navigator.pushReplacementNamed(context, AppRoutes.ownerDashboard);
        } else if (confirmedUserType == 'tenant') {
          print("Redirection vers le dashboard locataire");
          Navigator.pushReplacementNamed(context, AppRoutes.tenantDashboard);
        } else {
          throw Exception("Type d'utilisateur non reconnu: $confirmedUserType");
        }
      } on FirebaseAuthException catch (e) {
        print("Erreur FirebaseAuth: ${e.code} - ${e.message}");
        setState(() {
          switch (e.code) {
            case 'email-already-in-use':
              _errorMessage = 'Cet email est déjà utilisé.';
              break;
            case 'invalid-email':
              _errorMessage = 'Adresse email invalide.';
              break;
            case 'weak-password':
              _errorMessage = 'Mot de passe trop faible.';
              break;
            default:
              _errorMessage = 'Erreur : ${e.message}';
          }
        });
      } catch (e) {
        print("Erreur d'inscription: $e");
        setState(() {
          _errorMessage =
              'Erreur: ${e.toString().replaceAll('Exception: ', '')}';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Image.asset('assets/images/logo.png', height: 100),
                const SizedBox(height: 16),
                const Text('Créer un compte',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green)),
                const SizedBox(height: 24),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade800),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Nom
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Nom complet', Icons.person),
                  validator: (value) => (value == null || value.isEmpty)
                      ? 'Veuillez entrer votre nom'
                      : null,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration('Email', Icons.email),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Email invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Mot de passe
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecorationWithToggle(
                    'Mot de passe',
                    Icons.lock,
                    _obscurePassword,
                    () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Entrez un mot de passe';
                    }
                    if (value.length < 6) {
                      return '6 caractères minimum';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirmation mot de passe
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: _inputDecorationWithToggle(
                    'Confirmer le mot de passe',
                    Icons.lock_outline,
                    _obscureConfirmPassword,
                    () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Les mots de passe ne correspondent pas';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Sélection du rôle
                const Text('Je suis :',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<UserRole>(
                        title: const Text('Propriétaire'),
                        value: UserRole.owner,
                        groupValue: _selectedRole,
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<UserRole>(
                        title: const Text('Locataire'),
                        value: UserRole.tenant,
                        groupValue: _selectedRole,
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value!;
                          });
                        },
                        activeColor: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bouton S'inscrire
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'S\'INSCRIRE',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  InputDecoration _inputDecorationWithToggle(
    String label,
    IconData icon,
    bool obscure,
    VoidCallback toggle,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
        onPressed: toggle,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
