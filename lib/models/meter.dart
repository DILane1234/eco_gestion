enum MeterStatus { normal, offline, overload }

class Meter {
  final String id;
  final String name;
  final String roomId;
  final MeterStatus status;
  final double currentConsumption; // en kWh
  final double voltage; // en Volts
  final double current; // en Ampères
  final double power; // en VA
  final DateTime lastUpdated;
  
  Meter({
    required this.id,
    required this.name,
    required this.roomId,
    required this.status,
    required this.currentConsumption,
    required this.voltage,
    required this.current,
    required this.power,
    required this.lastUpdated,
  });
  
  factory Meter.fromJson(Map<String, dynamic> json) {
    return Meter(
      id: json['id'] as String,
      name: json['name'] as String,
      roomId: json['roomId'] as String,
      status: _parseStatus(json['status'] as String),
      currentConsumption: json['currentConsumption'] as double,
      voltage: json['voltage'] as double,
      current: json['current'] as double,
      power: json['power'] as double,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'roomId': roomId,
      'status': _statusToString(status),
      'currentConsumption': currentConsumption,
      'voltage': voltage,
      'current': current,
      'power': power,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
  
  static MeterStatus _parseStatus(String status) {
    switch (status) {
      case 'normal':
        return MeterStatus.normal;
      case 'offline':
        return MeterStatus.offline;
      case 'overload':
        return MeterStatus.overload;
      default:
        return MeterStatus.normal;
    }
  }
  
  static String _statusToString(MeterStatus status) {
    switch (status) {
      case MeterStatus.normal:
        return 'normal';
      case MeterStatus.offline:
        return 'offline';
      case MeterStatus.overload:
        return 'overload';
    }
  }
}