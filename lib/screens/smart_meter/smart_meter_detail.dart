import 'dart:async';

import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:eco_gestion/services/mqtt_service.dart';
import 'package:eco_gestion/services/notification_service.dart';
import 'package:eco_gestion/screens/smart_meter/meter_history_screen.dart';

class SmartMeterDetail extends StatefulWidget {
  final String meterId;
  final bool isOwner;

  const SmartMeterDetail({
    super.key,
    required this.meterId,
    required this.isOwner,
  });

  @override
  State<SmartMeterDetail> createState() => _SmartMeterDetailState();
}

class _SmartMeterDetailState extends State<SmartMeterDetail> {
  // Suppression de la ligne suivante
  // final FirebaseService _firebaseService = FirebaseService();
  final DatabaseReference _meterRef = FirebaseDatabase.instance.ref('compteurs');
  
  bool _isOn = true;
  bool _hasError = false;
  bool _isOnline = true;

  // Valeurs par défaut
  double _frequency = 49.9;
  double _powerFactor = 0.0;
  double _current = 0.0;
  double _power = 0.0;
  double _energy = 0.07;
  double _voltage = 216.3;

  StreamSubscription<DatabaseEvent>? _meterSubscription;

  @override
  void initState() {
    super.initState();
    _setupRealtimeUpdates();
  }

  @override
  void dispose() {
    _meterSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeUpdates() {
    _meterSubscription = _meterRef.child(widget.meterId).onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        
        setState(() {
          _isOn = data['isOn'] ?? true;
          _hasError = data['hasError'] ?? false;
          _isOnline = data['isOnline'] ?? true;
          
          _frequency = data['frequency']?.toDouble() ?? 49.9;
          _powerFactor = data['powerFactor']?.toDouble() ?? 0.0;
          _current = data['current']?.toDouble() ?? 0.0;
          _power = data['power']?.toDouble() ?? 0.0;
          _energy = data['energy']?.toDouble() ?? 0.07;
          _voltage = data['voltage']?.toDouble() ?? 216.3;
        });
        
        // Vérifier s'il y a une erreur et afficher une alerte si nécessaire
        if (_hasError && mounted) {
          _showErrorAlert();
        }
      }
    }, onError: (error) {
      print('Erreur de connexion à la base de données: $error');
    });
  }

  void _showErrorAlert() {
    // Éviter d'afficher plusieurs alertes
    if (!_hasError) return;
    
    // Créer une alerte dans Firebase
    _notificationService.createAlert(
      widget.meterId,
      'Défaut détecté',
      'Un problème a été détecté avec votre compteur intelligent.'
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Défaut détecté sur le compteur!'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Détails',
          textColor: Colors.white,
          onPressed: () {
            // Afficher plus de détails sur l'erreur
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Détail du défaut'),
                content: const Text('Un problème a été détecté avec votre compteur. Veuillez contacter le support technique.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _resetMeter() async {
    if (!widget.isOwner) return;
    
    try {
      await _meterRef.child(widget.meterId).update({
        'hasError': false,
      });
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compteur réinitialisé'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  final MqttService _mqttService = MqttService();
  final NotificationService _notificationService = NotificationService();
  
  Future<void> _toggleMeterPower() async {
    if (!widget.isOwner) return;
    
    try {
      // Envoyer la commande via MQTT
      _mqttService.sendCommand(widget.meterId, 'power', !_isOn);
      
      // Mettre à jour Firebase
      await _meterRef.child(widget.meterId).update({
        'isOn': !_isOn,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.grey[100],
      appBar: AppBar(
        title: const Text('Compteur Intelligent'),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // Navigation vers l'historique
              // Navigator.push(context, MaterialPageRoute(
              //   builder: (context) => MeterHistoryScreen(meterId: widget.meterId),
              // ));
            },
            tooltip: 'Historique',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Informations'),
                  content: const Text('Ce compteur intelligent vous permet de suivre votre consommation énergétique en temps réel.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fermer'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contrôles du compteur
              _buildControlPanel(isDarkMode),
              
              const SizedBox(height: 24),
              
              // Jauges de mesure
              _buildMeterGauges(isDarkMode),
              
              const SizedBox(height: 24),
              
              // Bouton vers l'historique détaillé
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MeterHistoryScreen(meterId: widget.meterId),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bar_chart),
                  label: const Text('Voir l\'historique détaillé'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlPanel(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ON/OFF Switch
          Column(
            children: [
              const Text(
                'on/off',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Switch(
                value: _isOn,
                onChanged: widget.isOwner 
                    ? (value) => _toggleMeterPower() 
                    : null,
                activeColor: Colors.green,
                activeTrackColor: Colors.green.withOpacity(0.5),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.grey.withOpacity(0.5),
              ),
            ],
          ),
          
          // Reset Button
          Column(
            children: [
              const Text(
                'Reset',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              ElevatedButton(
                onPressed: widget.isOwner ? _resetMeter : null,
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
                child: const Text('Arr', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          
          // Défaut indicator
          Column(
            children: [
              const Text(
                'défaut',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _hasError ? Colors.red : Colors.grey.shade300,
                ),
              ),
            ],
          ),
          
          // État indicator
          Column(
            children: [
              const Text(
                'état',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isOnline ? Colors.green : Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeterGauges(bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final cardColor = isDarkMode ? Colors.grey[900] : Colors.white;
    
    return Column(
      children: [
        // Première ligne: Fréquence et Facteur de puissance
        Row(
          children: [
            Expanded(
              child: _buildGauge(
                'fréquence',
                _frequency.toStringAsFixed(1),
                'Hz',
                _frequency / 255,
                0,
                255,
                Colors.green,
                cardColor,
                textColor,
              ),
            ),
            Expanded(
              child: _buildGauge(
                'cosphi',
                _powerFactor.toString(),
                '',
                _powerFactor,
                0,
                1,
                Colors.green,
                cardColor,
                textColor,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Deuxième ligne: Intensité et Puissance
        Row(
          children: [
            Expanded(
              child: _buildGauge(
                'Intensité',
                _current.toStringAsFixed(1),
                'A',
                _current / 100,
                0,
                100,
                Colors.green,
                cardColor,
                textColor,
              ),
            ),
            Expanded(
              child: _buildGauge(
                'Puissance',
                _power.toStringAsFixed(1),
                'W',
                _power / 1000,
                0,
                1000,
                Colors.green,
                cardColor,
                textColor,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Troisième ligne: Énergie et Tension
        Row(
          children: [
            Expanded(
              child: _buildGauge(
                'Énergie',
                _energy.toStringAsFixed(2),
                'kWh',
                _energy / 10000,
                0,
                10000,
                Colors.green,
                cardColor,
                textColor,
              ),
            ),
            Expanded(
              child: _buildGauge(
                'Tension',
                _voltage.toStringAsFixed(1),
                'V',
                _voltage / 300,
                0,
                300,
                Colors.green,
                cardColor,
                textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGauge(
    String label,
    String value,
    String unit,
    double percent,
    double min,
    double max,
    Color color,
    Color? cardColor,
    Color textColor,
  ) {
    // Limiter le pourcentage entre 0 et 1
    percent = percent.clamp(0.0, 1.0);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          CircularPercentIndicator(
            radius: 55.0,
            lineWidth: 8.0,
            percent: percent,
            center: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                children: [
                  TextSpan(text: value),
                  TextSpan(
                    text: unit,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            progressColor: color,
            backgroundColor: Colors.grey.shade200,
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
            animationDuration: 1000,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                min.toInt().toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              Text(
                max.toInt().toString(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
