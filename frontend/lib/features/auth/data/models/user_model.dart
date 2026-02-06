class User {
  final String id;
  final String email;
  final String username;
  final String createdAt;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.createdAt,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String? ?? 'User',
      createdAt: json['createdAt'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
