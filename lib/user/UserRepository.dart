import '../api/BaseApiClient.dart';
import 'User.dart';

class UserApiClient extends BaseApiClient {
  UserApiClient({
    required super.dio,
    required super.secureStorage,
    required super.baseUrl,
  });

  Future<User> getUser() async {
    try {
      final response = await dio.get('$baseUrl/users/me');
      return User.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }
}

class UserRepository {
  final UserApiClient apiClient;

  UserRepository({required this.apiClient});

  Future<User?> getUser() async {
    try {
      final userResponse =
          await apiClient.getUser(); // Assume this calls an API
      return userResponse;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }
}
