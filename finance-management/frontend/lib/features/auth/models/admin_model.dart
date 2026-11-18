/// Represents an authenticated Admin user session
class AdminModel {
  final String id;
  final String email;
  final String role;

  const AdminModel({
    required this.id,
    required this.email,
    required this.role,
  });

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? 'admin',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'role': role,
      };
}

