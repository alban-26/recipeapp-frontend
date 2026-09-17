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

      // Kein Token-Schreiben mehr hier.
      // Vorher wurde auf data['accessToken'] geprueft - Keycloak liefert aber
      // 'access_token'. Der Block war toter Code und hat nur die
      // Zustaendigkeit verwischt. Das AuthRepository speichert jetzt.
      return response.data as Map<String, dynamic>;
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
    required String password,
  }) async {
    try {
      final response = await dio.post(
        '$baseUrl/users/register',
        data: {
          'email': email,
          'password': password,
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

  // logout() entfernt - das macht jetzt AuthRepository ueber den TokenStore.
}
