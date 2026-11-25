import 'dart:async';

import 'package:dio/dio.dart';

import 'TokenStore.dart';

/// Refresh Token ist serverseitig endgueltig ungueltig -> ausloggen.
class SessionExpiredException implements Exception {
  final String reason;

  /// Stand von [TokenStore.epoch], als der Refresh begann - damit nur genau
  /// DIESE Session beendet wird und nicht ein inzwischen erfolgter neuer Login.
  final int epoch;

  SessionExpiredException(this.reason, {required this.epoch});
  @override
  String toString() => 'SessionExpiredException: $reason';
}

/// Refresh technisch fehlgeschlagen (kein Netz, Timeout, 5xx) -> Tokens behalten.
class TemporaryAuthFailure implements Exception {
  final String reason;
  TemporaryAuthFailure(this.reason);
  @override
  String toString() => 'TemporaryAuthFailure: $reason';
}

/// Haengt den Access Token an und erneuert ihn bei 401.
/// Wird GENAU EINMAL registriert - in main.dart, nicht pro API-Client.
class AuthInterceptor extends Interceptor {
  /// Haupt-Instanz, fuer den Retry des urspruenglichen Requests.
  final Dio dio;

  /// Eigene Instanz OHNE Interceptor, nur fuer den Refresh-Call.
  final Dio refreshDio;

  final TokenStore tokenStore;

  /// FEST auf den Auth-Service. Vorher kam die baseUrl aus der jeweiligen
  /// BaseApiClient-Subklasse - lokal ging der Refresh dadurch an Port 8081
  /// statt 8082 und lief in eine Endlosschleife.
  final String authBaseUrl;

  Future<void>? _refreshInFlight;

  AuthInterceptor({
    required this.dio,
    required this.refreshDio,
    required this.tokenStore,
    required this.authBaseUrl,
  });

  /// Endpunkte ohne Token. Quarkus lehnt einen mitgeschickten UNGUELTIGEN
  /// Bearer Token auch auf "permit"-Pfaden mit 401 ab (proactive auth) -
  /// wer hier einen alten Token anhaengt, kann sich nicht mehr einloggen.
  static const _publicPaths = <String>[
    '/users/login',
    '/users/refresh',
    '/users/register',
    '/users/forgot-password',
    '/users/logout',
  ];

  static const _retryFlag = '__auth_retried';

  bool _isPublic(String path) => _publicPaths.any(path.contains);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isPublic(options.path)) {
      options.headers.remove('Authorization');
      return handler.next(options);
    }
    final token = await tokenStore.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;

    final shouldRefresh = err.response?.statusCode == 401 &&
        !_isPublic(options.path) &&
        options.extra[_retryFlag] != true;

    if (!shouldRefresh) return handler.next(err);

    // --- Block 1: Refresh -------------------------------------------------
    // Hat ein paralleler Request den Token inzwischen schon erneuert? Dann
    // ist dieser 401 Schnee von gestern und es reicht, mit dem aktuellen
    // Token zu wiederholen - ohne einen weiteren Refresh auszuloesen.
    final currentToken = await tokenStore.readAccessToken();
    final alreadyRefreshed = currentToken != null &&
        options.headers['Authorization'] != 'Bearer $currentToken';

    try {
      if (!alreadyRefreshed) await _refreshSingleFlight();
    } on SessionExpiredException catch (e) {
      await tokenStore.expire(e.reason, ifEpoch: e.epoch);
      return handler.next(err);
    } on TemporaryAuthFailure catch (e) {
      print('[AuthInterceptor] Refresh vorerst fehlgeschlagen, '
          'Session bleibt bestehen: ${e.reason}');
      return handler.next(err);
    } catch (e) {
      print('[AuthInterceptor] Unerwarteter Fehler beim Refresh: $e');
      return handler.next(err);
    }

    // --- Block 2: Retry ---------------------------------------------------
    // Bewusst GETRENNT vom Refresh. Vorher standen beide im selben try/catch,
    // deshalb loeschte ein 500 auf dem wiederholten Request die Tokens,
    // obwohl der Refresh davor erfolgreich war.
    try {
      final newToken = await tokenStore.readAccessToken();
      if (newToken != null) {
        options.headers['Authorization'] = 'Bearer $newToken';
      }
      options.extra[_retryFlag] = true;

      final response = await dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      print('[AuthInterceptor] Retry fehlgeschlagen '
          '(HTTP ${e.response?.statusCode}) - Session bleibt bestehen');
      return handler.next(e);
    } catch (e) {
      print('[AuthInterceptor] Retry fehlgeschlagen: $e');
      return handler.next(err);
    }
  }

  /// Zehn parallele 401 loesen genau einen Refresh aus, die anderen neun
  /// warten auf dessen Ergebnis.
  Future<void> _refreshSingleFlight() {
    final running = _refreshInFlight;
    if (running != null) return running;

    final future = _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
    _refreshInFlight = future;
    return future;
  }

  Future<void> _performRefresh() async {
    final epoch = tokenStore.epoch;

    final String? refreshToken;
    try {
      refreshToken = await tokenStore.readRefreshToken();
    } on TokenStorageException catch (e) {
      // Speicher nicht lesbar heisst nicht "kein Token" - Session behalten.
      throw TemporaryAuthFailure('Token-Speicher nicht lesbar: ${e.cause}');
    }
    if (refreshToken == null) {
      throw SessionExpiredException('kein Refresh Token im Storage',
          epoch: epoch);
    }

    final Response response;
    try {
      response = await refreshDio.post(
        '$authBaseUrl/users/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(
          validateStatus: (_) => true, // Status selbst auswerten
          headers: {'Content-Type': 'application/json'},
        ),
      );
    } on DioException catch (e) {
      // Kein Response: kein Netz, Timeout, DNS, Verbindungsabbruch.
      // Frueher lief hier deleteAll().
      throw TemporaryAuthFailure('kein Response (${e.type.name})');
    } catch (e) {
      throw TemporaryAuthFailure('Transportfehler: $e');
    }

    final status = response.statusCode ?? 0;

    if (status == 200) {
      final data = response.data;
      final access = data is Map ? data['access_token'] as String? : null;
      final refresh = data is Map ? data['refresh_token'] as String? : null;
      if (access == null || refresh == null) {
        throw TemporaryAuthFailure('Antwort ohne Tokens (HTTP 200)');
      }
      final saved = await tokenStore.saveIfCurrent(
        epoch,
        accessToken: access,
        refreshToken: refresh,
      );
      if (!saved) {
        // Waehrend des Refreshs wurde aus- oder neu eingeloggt.
        throw TemporaryAuthFailure('Session hat sich waehrend des Refreshs geaendert');
      }
      print('[AuthInterceptor] Refresh ok');
      return;
    }

    if (isRefreshTokenRejected(status, response.data)) {
      throw SessionExpiredException(
          'Server lehnte Refresh Token ab (HTTP $status)',
          epoch: epoch);
    }

    throw TemporaryAuthFailure('Refresh fehlgeschlagen (HTTP $status)');
  }

  /// Hat der Server den Refresh Token ENDGUELTIG abgelehnt?
  ///
  /// Nur dann darf ausgeloggt werden. Der Statuscode allein reicht dafuer
  /// nicht: der user-management-Service hat lange fuer JEDEN Fehler
  /// "400 invalid_grant" geschickt - auch wenn bloss Keycloak kurz nicht
  /// erreichbar war. Jeder, dessen Access Token in so einem Moment ablief,
  /// wurde ausgeloggt.
  static bool isRefreshTokenRejected(int status, Object? body) {
    if (status != 400 && status != 401) return false;
    if (body is! Map) return false;

    // Aktueller Server: sagt es ausdruecklich.
    final explicit = body['session_expired'];
    if (explicit is bool) return explicit;

    // Aelterer Server: Keycloaks Antwort steckt nur in der Beschreibung.
    // "Refresh failed: 400" = Keycloak hat den Token abgelehnt. Alles andere
    // ("Refresh failed: 503", "Connection refused: ...") war ein Problem
    // zwischen Service und Keycloak und sagt nichts ueber die Session.
    return body['error'] == 'invalid_grant' &&
        body['error_description'] == 'Refresh failed: 400';
  }
}
