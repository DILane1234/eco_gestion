class Consumption {
  final String id;
  final String meterId;
  final String roomId;
  final double value; // en kWh
  final DateTime timestamp;
  final double? cost; // coût estimé basé sur le tarif
  
  Consumption({
    required this.id,
    required this.meterId,
    required this.roomId,
    required this.value,
    required this.timestamp,
    this.cost,
  });
  
  factory Consumption.fromJson(Map<String, dynamic> json) {
    return Consumption(
      id: json['id'] as String,
      meterId: json['meterId'] as String,
      roomId: json['roomId'] as String,
      value: json['value'] as double,
      timestamp: DateTime.parse(json['timestamp'] as String),
      cost: json['cost'] as double?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meterId': meterId,
      'roomId': roomId,
      'value': value,
      'timestamp': timestamp.toIso8601String(),
      'cost': cost,
    };
  }
}