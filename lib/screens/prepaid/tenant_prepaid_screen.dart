import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/prepaid_service.dart';
import '../../models/prepaid_system.dart';

class TenantPrepaidScreen extends StatefulWidget {
  const TenantPrepaidScreen({super.key});

  @override
  State<TenantPrepaidScreen> createState() => _TenantPrepaidScreenState();
}

class _TenantPrepaidScreenState extends State<TenantPrepaidScreen> {
  final PrepaidService _prepaidService = PrepaidService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Compte Prépayé'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('meters')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final meters = snapshot.data!.docs;

          if (meters.isEmpty) {
            return const Center(
              child: Text('Aucun compteur assigné'),
            );
          }

          final meterId = meters.first.id;

          return StreamBuilder<PrepaidSystem>(
            stream: _prepaidService.getPrepaidSystemStream(meterId),
            builder: (context, prepaidSnapshot) {
              if (!prepaidSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final prepaidSystem = prepaidSnapshot.data!;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Carte principale avec le solde
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Solde actuel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: prepaidSystem.isActive
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    prepaidSystem.isActive
                                        ? 'Actif'
                                        : 'Inactif',
                                    style: TextStyle(
                                      color: prepaidSystem.isActive
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${prepaidSystem.remainingEnergy.toStringAsFixed(1)} kWh',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            LinearProgressIndicator(
                              value: prepaidSystem.consumedEnergy /
                                  prepaidSystem.energyCredit,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                prepaidSystem.isLowCredit()
                                    ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Consommation: ${prepaidSystem.consumedEnergy.toStringAsFixed(1)} kWh',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Historique des recharges',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    StreamBuilder<QuerySnapshot>(
                      stream: _prepaidService.getRechargeHistory(meterId),
                      builder: (context, historySnapshot) {
                        if (!historySnapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final history = historySnapshot.data!.docs;

                        if (history.isEmpty) {
                          return const Center(
                            child: Text('Aucun historique disponible'),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final recharge =
                                history[index].data() as Map<String, dynamic>;
                            final timestamp =
                                recharge['timestamp'] as Timestamp?;
                            final amount = recharge['amount'] as double?;
                            final energyCredit =
                                recharge['energyCredit'] as double?;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.electric_bolt,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                title: Text(
                                  '${amount?.toStringAsFixed(0) ?? 0} FCFA',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${energyCredit?.toStringAsFixed(1) ?? 0} kWh',
                                ),
                                trailing: Text(
                                  timestamp != null
                                      ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year}'
                                      : 'Date inconnue',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
