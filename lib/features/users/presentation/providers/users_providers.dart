import '../../data/models/user_models.dart';
import '../../data/users_api_service.dart';

class UsersState {
  List<AppUser> users = const [];
  bool isLoading = false;

  final UsersApiService _api = UsersApiService();

  Future<void> loadUsers() async {
    isLoading = true;
    users = await _api.fetchUsers();
    isLoading = false;
  }
}
