import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/AuthClient.dart';

class AuthRepository {
  final AuthClient authClient;
  final FlutterSecureStorage storage;

  AuthRepository({
    required this.authClient,
    required this.storage,
  });

  Future<void> login(String email, String password) async {
    logout();
    final response = await authClient.loginUser(email, password);

    if (response['error'] == true) {
      throw Exception(
          response['message']); // Throwing exception for Bloc/UI handling
    }

    await _storeTokens(response);
  }

  Future<void> logout() async {
    try {
      await storage.delete(key: 'access_token');
      await storage.delete(key: 'refresh_token');
    } catch (e) {
      print('Error during sign out: $e');
    }
  }

  Future<void> register(
      String email, String password) async {
    try {
      final response = await authClient.registerUser(
        email: email,
        password: password
      );
      print('User registered successfully: $response');
    } catch (e) {
      print('Registration failed: $e');
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await authClient.forgotPassword(email);
      print('Forgot password request sent: $response');
    } catch (e) {
      print('Forgot password request failed: $e');
      rethrow;
    }
  }

  Future<void> _storeTokens(Map<String, dynamic> tokens) async {
    await storage.write(key: 'access_token', value: tokens['access_token']);
    await storage.write(key: 'refresh_token', value: tokens['refresh_token']);
  }

  Future<Map<String, String>?> getStoredTokens() async {
    try {
      final accessToken = await storage.read(key: 'access_token');
      final refreshToken = await storage.read(key: 'refresh_token');

      if (accessToken != null && refreshToken != null) {
        return {
          'access_token': accessToken,
          'refresh_token': refreshToken,
        };
      }
    } catch (e) {
      print('Error fetching stored tokens: $e');
    }

    return null;
  }
}
