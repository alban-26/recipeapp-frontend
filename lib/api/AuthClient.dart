import 'package:dio/dio.dart';

import 'BaseApiClient.dart';

class AuthClient extends BaseApiClient {
  AuthClient({
    required super.dio,
    required super.secureStorage,
    required super.baseUrl,
  });

  Future<Map<String, dynamic>> loginUser(String email, String password) async {
    try {
      final response = await dio.post(
        '$baseUrl/users/login',
        data: {
          'username': email,
          'password': password,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      // Extract tokens and store securely
      final data = response.data;
      if (data != null && data['accessToken'] != null) {
        await secureStorage.write(
            key: 'access_token', value: data['accessToken']);
        if (data['refreshToken'] != null) {
          await secureStorage.write(
              key: 'refresh_token', value: data['refreshToken']);
        }
      }

      return data;
    } on DioException catch (e) {
      if (e.response != null) {
        final errorData = e.response?.data;
        final errorMessage = errorData is Map<String, dynamic> &&
                errorData.containsKey('error_description')
            ? errorData['error_description']
            : 'Login failed. Please try again.';

        return {'error': true, 'message': errorMessage};
      } else {
        return {
          'error': true,
          'message': 'Network error. Please check your connection.'
        };
      }
    } catch (e) {
      return {'error': true, 'message': 'An unexpected error occurred.'};
    }
  }

  Future<Map<String, dynamic>> registerUser({
    required String email,
    required String password
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/users/register',
        data: {
          'email': email,
          'password': password
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      print("Registration error: ${e.response?.data}");
      return {'error': e.response?.data['error'] ?? 'Registration failed'};
    } catch (e) {
      print("Unexpected error: $e");
      return {'error': 'Unexpected error occurred'};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      await dio.post(
        '$baseUrl/users/forgot-password',
        data: {'email': email},
      );

      return {
        'success': true,
        'message': 'If the email exists, a reset link has been sent.'
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Network error. Please try again.'
      };
    }
  }



  Future<void> logout() async {
    await secureStorage.delete(key: 'access_token');
    await secureStorage.delete(key: 'refresh_token');
  }
}
