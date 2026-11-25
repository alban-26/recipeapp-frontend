import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Der sichere Speicher liess sich nicht lesen (z.B. Keystore/Keychain kurz
/// nicht verfuegbar). Das heisst NICHT, dass kein Token da ist.
class TokenStorageException implements Exception {
  final Object cause;
  TokenStorageException(this.cause);
  @override
  String toString() => 'TokenStorageException: $cause';
}

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

  /// Zaehlt jede Aenderung an der Session (Login, Refresh, Logout).
  ///
  /// Damit laesst sich erkennen, ob ein lange laufender Vorgang noch zur
  /// aktuellen Session gehoert. Ohne das konnte ein verspaeteter Request der
  /// alten Session die frisch gespeicherten Tokens eines neuen Logins loeschen.
  int get epoch => _epoch;
  int _epoch = 0;

  TokenStore(this._storage);

  Future<String?> readAccessToken() async {
    try {
      return await _storage.read(key: _kAccess);
    } catch (e) {
      print('[TokenStore] Access Token nicht lesbar: $e');
      return null;
    }
  }

  /// Liefert den Refresh Token, oder null, wenn wirklich keiner gespeichert ist.
  ///
  /// Wirft [TokenStorageException], wenn der Speicher nicht lesbar ist.
  /// Vorher wurde auch dann null geliefert - und "kein Token" fuehrte direkt
  /// zum Logout samt Loeschen der (eigentlich noch vorhandenen) Tokens.
  Future<String?> readRefreshToken() async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await _storage.read(key: _kRefresh);
      } catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 150 * (attempt + 1)));
        }
      }
    }
    print('[TokenStore] Refresh Token nicht lesbar: $lastError');
    throw TokenStorageException(lastError ?? 'unbekannt');
  }

  /// Ist der Speicher nicht lesbar, wird die Session als vorhanden angenommen:
  /// lieber mit gespeicherten Daten weiterarbeiten, als wegen eines
  /// Lesefehlers auf dem Login-Screen zu landen.
  Future<bool> hasSession() async {
    try {
      return (await readRefreshToken()) != null;
    } on TokenStorageException {
      return true;
    }
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _epoch++;
    await _storage.write(key: _kRefresh, value: refreshToken);
    await _storage.write(key: _kAccess, value: accessToken);
  }

  /// Wie [save], aber nur, wenn die Session seit [epoch] unveraendert ist.
  /// Liefert false, wenn inzwischen aus- oder neu eingeloggt wurde - das
  /// Ergebnis eines alten Refreshs darf dann nichts mehr ueberschreiben.
  Future<bool> saveIfCurrent(
    int epoch, {
    required String accessToken,
    required String refreshToken,
  }) async {
    if (epoch != _epoch) return false;
    await save(accessToken: accessToken, refreshToken: refreshToken);
    return true;
  }

  /// Stiller Logout - wenn der Nutzer selbst ausloggt.
  Future<void> clear() async {
    _epoch++;
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
  }

  /// Session ist serverseitig tot. Loescht und benachrichtigt den SessionCubit.
  /// Das ist der EINZIGE Pfad, auf dem unfreiwillig geloescht werden darf.
  ///
  /// Mit [ifEpoch] passiert nur etwas, wenn die Session seitdem unveraendert
  /// ist (siehe [epoch]).
  Future<void> expire(String reason, {int? ifEpoch}) async {
    if (ifEpoch != null && ifEpoch != _epoch) {
      print('[TokenStore] Ablauf einer alten Session ignoriert: $reason');
      return;
    }
    print('[TokenStore] Session beendet: $reason');
    await clear();
    if (!_expired.isClosed) _expired.add(null);
  }

  Future<void> dispose() => _expired.close();
}
