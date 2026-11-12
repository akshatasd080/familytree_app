class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.role = 'user',
  });

  final String id;
  final String name;
  final String email;
  final String role;
}
