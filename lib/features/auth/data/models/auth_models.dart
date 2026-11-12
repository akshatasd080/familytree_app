class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.roleId,
    this.roleName,
    this.mustChangePassword = false,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? roleId;
  final String? roleName;
  final bool mustChangePassword;

  bool get isSuperAdmin =>
      (roleName ?? '').toLowerCase() == 'superadmin';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final role = json['role'];
    return AuthUser(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      phone: json['phone']?.toString(),
      roleId: (json['roleId'] ?? json['role_id'])?.toString(),
      roleName: role is Map
          ? role['name']?.toString()
          : json['roleName']?.toString(),
      mustChangePassword: json['mustChangePassword'] == true ||
          json['must_change_password'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'roleId': roleId,
        'role': roleName == null ? null : {'name': roleName},
        'mustChangePassword': mustChangePassword,
      };

  AuthUser copyWith({bool? mustChangePassword}) => AuthUser(
        id: id,
        name: name,
        email: email,
        phone: phone,
        roleId: roleId,
        roleName: roleName,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      );
}
