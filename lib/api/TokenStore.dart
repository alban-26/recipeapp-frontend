import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Einzige Stelle, die Tokens liest, schreibt oder loescht.
///
/// Vorher lag das an vier Stellen gleichzeitig: AuthClient, AuthRepository,
/// BaseApiClient und StorageRepository - teilweise mit unterschiedlichen
/// Key-Namen ('accessToken' vs 'access_token' vs 'auth_token').
class TokenStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';

  final FlutterSecureStorage _storage;

  /// Feuert NUR, wenn der Server den Refresh Token endgueltig abgelehnt hat.
  /// Nicht bei Netzwerkfehlern, nicht bei 500ern.
  Stream<void> get onSessionExpired => _expired.stream;
  final _expired = StreamController<void>.broadcast();

  TokenStore(this._storage);

  Future<String?> readAccessToken() async {
    try {
      return await _storage.read(key: _kAccess);
    } catch (e) {
      print('[TokenStore] Access Token nicht lesbar: $e');
      return null;
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _kRefresh);
    } catch (e) {
      print('[TokenStore] Refresh Token nicht lesbar: $e');
      return null;
    }
  }

  Future<bool> hasSession() async => (await readRefreshToken()) != null;

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kRefresh, value: refreshToken);
    await _storage.write(key: _kAccess, value: accessToken);
  }

  /// Stiller Logout - wenn der Nutzer selbst ausloggt.
  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  /// Session ist serverseitig tot. Loescht und benachrichtigt den SessionCubit.
  /// Das ist der EINZIGE Pfad, auf dem unfreiwillig geloescht werden darf.
  Future<void> expire(String reason) async {
    print('[TokenStore] Session beendet: $reason');
    await clear();
    if (!_expired.isClosed) _expired.add(null);
  }

  Future<void> dispose() => _expired.close();
}
