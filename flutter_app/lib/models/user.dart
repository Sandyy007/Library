class User {
  final int id;
  final String username;
  final String role;
  final bool mustChangePassword;

  User({
    required this.id,
    required this.username,
    required this.role,
    this.mustChangePassword = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      mustChangePassword: json['mustChangePassword'] == true ||
          json['mustChangePassword'] == 1 ||
          json['must_change_password'] == true ||
          json['must_change_password'] == 1,
    );
  }
}
