class PrepaidSystem {
  final String meterId;
  final double creditAmount; // Montant en FCFA
  final double energyCredit; // Montant en kWh
  final double consumedEnergy; // Énergie consommée en kWh
  final double remainingEnergy; // Énergie restante en kWh
  final bool isActive; // État du compteur (actif/inactif)
  final DateTime lastUpdate;
  final double kWhPrice; // Prix du kWh en FCFA
  final bool lowCreditAlert; // Alerte de crédit faible

  PrepaidSystem({
    required this.meterId,
    required this.creditAmount,
    required this.energyCredit,
    required this.consumedEnergy,
    required this.remainingEnergy,
    required this.isActive,
    required this.lastUpdate,
    required this.kWhPrice,
    required this.lowCreditAlert,
  });

  factory PrepaidSystem.fromMap(Map<String, dynamic> map) {
    return PrepaidSystem(
      meterId: map['meterId'] ?? '',
      creditAmount: (map['creditAmount'] ?? 0.0).toDouble(),
      energyCredit: (map['energyCredit'] ?? 0.0).toDouble(),
      consumedEnergy: (map['consumedEnergy'] ?? 0.0).toDouble(),
      remainingEnergy: (map['remainingEnergy'] ?? 0.0).toDouble(),
      isActive: map['isActive'] ?? false,
      lastUpdate: DateTime.fromMillisecondsSinceEpoch(map['lastUpdate'] ?? 0),
      kWhPrice:
          (map['kWhPrice'] ?? 100.0).toDouble(), // Prix par défaut: 100 FCFA
      lowCreditAlert: map['lowCreditAlert'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'meterId': meterId,
      'creditAmount': creditAmount,
      'energyCredit': energyCredit,
      'consumedEnergy': consumedEnergy,
      'remainingEnergy': remainingEnergy,
      'isActive': isActive,
      'lastUpdate': lastUpdate.millisecondsSinceEpoch,
      'kWhPrice': kWhPrice,
      'lowCreditAlert': lowCreditAlert,
    };
  }

  // Méthode pour calculer l'énergie à partir du montant
  static double calculateEnergyFromAmount(double amount, double kWhPrice) {
    return amount / kWhPrice;
  }

  // Méthode pour vérifier si le crédit est faible (moins de 20%)
  bool isLowCredit() {
    return remainingEnergy <= (energyCredit * 0.2);
  }

  // Méthode pour mettre à jour la consommation
  PrepaidSystem updateConsumption(double newConsumption) {
    final newRemainingEnergy = energyCredit - newConsumption;
    final newLowCreditAlert = newRemainingEnergy <= (energyCredit * 0.2);

    return PrepaidSystem(
      meterId: meterId,
      creditAmount: creditAmount,
      energyCredit: energyCredit,
      consumedEnergy: newConsumption,
      remainingEnergy: newRemainingEnergy,
      isActive: newRemainingEnergy > 0,
      lastUpdate: DateTime.now(),
      kWhPrice: kWhPrice,
      lowCreditAlert: newLowCreditAlert,
    );
  }
}
