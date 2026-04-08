class UserModel {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? bio;
  final String? phone;
  final bool isHost;
  final bool isSuperhost;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.bio,
    this.phone,
    this.isHost = false,
    this.isSuperhost = false,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      firstName: json['firstName'] as String,
      lastName: json['lastName'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      phone: json['phone'] as String?,
      isHost: json['isHost'] as bool? ?? false,
      isSuperhost: json['isSuperhost'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'phone': phone,
      'isHost': isHost,
      'isSuperhost': isSuperhost,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
