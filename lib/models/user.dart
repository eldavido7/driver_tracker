import 'session.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final List<SessionModel>? sessions;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.sessions,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      sessions: json['sessions'] != null
          ? (json['sessions'] as List<dynamic>)
                .map((s) => SessionModel.fromJson(s as Map<String, dynamic>))
                .toList()
          : null,
    );
  }
}
