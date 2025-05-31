class Room {
  final String id;
  final String name;
  final String? tenantId;
  final String? meterId;
  final String houseId;

  Room({
    required this.id,
    required this.name,
    required this.houseId,
    this.tenantId,
    this.meterId,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      houseId: json['houseId'] as String,
      tenantId: json['tenantId'] as String?,
      meterId: json['meterId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'houseId': houseId,
      'tenantId': tenantId,
      'meterId': meterId,
    };
  }
}
