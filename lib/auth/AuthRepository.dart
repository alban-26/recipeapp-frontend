import '../api/AuthClient.dart';
import '../api/TokenStore.dart';

class AuthRepository {
  final AuthClient authClient;
  final TokenStore tokenStore;

  AuthRepository({
    required this.authClient,
    required this.tokenStore,
  });

  Future<void> login(String email, String password) async {
    // WICHTIG: await.
    // Vorher stand hier ein nacktes "logout();". Die Loeschungen konnten
    // dadurch NACH dem Speichern der neuen Tokens landen - Login erfolgreich,
    // Tokens trotzdem weg.
    await tokenStore.clear();

    final response = await authClient.loginUser(email, password);

    if (response['error'] == true) {
      throw Exception(response['message']);
    }

    final access = response['access_token'] as String?;
    final refresh = response['refresh_token'] as String?;

    if (access == null || refresh == null) {
      throw Exception('Login-Antwort enthielt keine Tokens.');
    }

    await tokenStore.save(accessToken: access, refreshToken: refresh);
  }

  Future<void> logout() async {
    // TODO Schritt 6: vorher /users/logout aufrufen, damit die Session auch
    // bei Keycloak beendet wird. Aktuell bleibt der Refresh Token
    // serverseitig gueltig.
    await tokenStore.clear();
  }

  Future<void> register(String email, String password) async {
    try {
      final response = await authClient.registerUser(
        email: email,
        password: password,
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

  /// Ersetzt das alte getStoredTokens(). Nur der SessionCubit hat es benutzt,
  /// und der wollte nur wissen: gibt es ueberhaupt eine Session?
  Future<bool> hasSession() => tokenStore.hasSession();
}
