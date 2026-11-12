import 'models/user_models.dart';

class UsersApiService {
  // Future<List<AppUser>> fetchUsers() async { ... }

  Future<List<AppUser>> fetchUsers() async {
    return const [
      AppUser(id: '1', name: 'Admin', email: 'admin@example.com', role: 'admin'),
    ];
  }
}
