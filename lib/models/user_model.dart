class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? phoneNumber;
  final String userType; // 'owner' ou 'tenant'
  final String? photoURL;
  final Map<String, dynamic>? additionalData;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.phoneNumber,
    required this.userType,
    this.photoURL,
    this.additionalData,
  });

  // Conversion depuis Firestore
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? map['name'],
      phoneNumber: map['phoneNumber'],
      userType: map['userType'] ?? 'tenant',
      photoURL: map['photoURL'],
      additionalData: map['additionalData'],
    );
  }

  // Conversion vers Firestore
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'userType': userType,
      'photoURL': photoURL,
      'additionalData': additionalData,
    };
  }

  // Créer une copie avec des modifications
  UserModel copyWith({
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    Map<String, dynamic>? additionalData,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      userType: userType,
      photoURL: photoURL ?? this.photoURL,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}