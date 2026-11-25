import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/user/UserRepository.dart';

import '../api/TokenStore.dart';
import '../auth/AuthRepository.dart';
import '../offline/OfflineData.dart';
import '../user/User.dart';
import 'SessionState.dart';

class SessionCubit extends Cubit<SessionState> {
  static const _userKey = 'session_user';

  final AuthRepository authRepo;
  final UserRepository userRepository;
  final TokenStore tokenStore;

  /// Lokal gespeicherte Daten (Offline-Modus). Optional, damit der Cubit auch
  /// ohne sie funktioniert.
  final OfflineData? offlineData;

  late final StreamSubscription<void> _expirySub;

  User get user => (state as Authenticated).user;

  SessionCubit({
    required this.authRepo,
    required this.userRepository,
    required this.tokenStore,
    this.offlineData,
  }) : super(UnknownSessionState()) {
    // Wenn der Refresh Token serverseitig endgueltig abgelehnt wurde, meldet
    // der TokenStore das hier und die App springt sofort zum Login.
    // Die lokal gespeicherten Daten bleiben dabei liegen: meldet sich
    // derselbe Nutzer wieder an, gehen wartende Aenderungen nicht verloren.
    _expirySub = tokenStore.onSessionExpired.listen((_) {
      if (state is! Unauthenticated) emit(Unauthenticated());
    });

    attemptAutoLogin();
  }

  /// Entscheidet beim Start, ob jemand angemeldet ist.
  ///
  /// Massgeblich sind allein die gespeicherten Tokens - NICHT, ob der Server
  /// gerade antwortet. Vorher fuehrte jeder Fehler von /users/me (kein Netz,
  /// Timeout, Server-Neustart) auf den Login-Screen, obwohl die Session
  /// voellig in Ordnung war.
  Future<void> attemptAutoLogin() async {
    try {
      if (!await authRepo.hasSession()) {
        emit(Unauthenticated());
        return;
      }

      // Wer angemeldet ist, steht lokal: gespeichert bzw. im Access Token.
      final local = await _localUser();
      if (local != null) {
        await _startSession(local);
        // Im Hintergrund abgleichen. Lehnt der Server dabei den Refresh
        // Token ab, meldet sich der TokenStore (siehe oben).
        unawaited(_refreshUser());
        return;
      }

      // Nichts Lokales da (sollte praktisch nie vorkommen): Server fragen.
      final remote = await userRepository.getUser();
      if (remote != null) {
        await _startSession(remote);
      } else {
        // Die Tokens bleiben erhalten - beim naechsten Start mit Verbindung
        // greift der Auto-Login wieder.
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated());
    }
  }

  /// Nach erfolgreichem Login (Tokens sind gespeichert).
  void showSession() async {
    try {
      final user = await userRepository.getUser() ?? await _userFromToken();
      if (user != null) {
        await _startSession(user);
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      // Kein eigener Fehler-State: fuer den gibt es keine Seite, die App
      // bliebe leer. Auf dem Login-Screen kann man es einfach erneut versuchen.
      emit(Unauthenticated());
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await authRepo.login(email, password);
      final user = await userRepository.getUser() ?? await _userFromToken();
      if (user != null) {
        await _startSession(user);
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthErrorState(errorMessage: ''));
    }
  }

  Future<void> register(
    User user,
    String email,
    String password,
  ) async {
    try {
      await authRepo.register(user.email, password);
      emit(Registered());
    } catch (e) {
      emit(AuthErrorState(errorMessage: ''));
    }
  }

  void logout() async {
    await authRepo.logout();
    // Auf einem geteilten Geraet soll nach dem Abmelden nichts liegen bleiben.
    try {
      await offlineData?.wipe();
    } catch (e) {
      print('Lokale Daten nicht loeschbar: $e');
    }
    emit(Unauthenticated());
  }

  // --- intern ---------------------------------------------------------------

  Future<User?> _userFromToken() async =>
      User.fromAccessToken(await tokenStore.readAccessToken());

  Future<User?> _localUser() async {
    // Der Token entscheidet, WER angemeldet ist. Die gespeicherte Kopie ist
    // nur der Notnagel, falls der Token-Speicher gerade nicht lesbar ist.
    final fromToken = await _userFromToken();
    if (fromToken != null) return fromToken;
    try {
      final raw = await offlineData?.store.readJson(_userKey);
      if (raw is Map) return User.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {}
    return null;
  }

  Future<void> _startSession(User user) async {
    try {
      // Gehoeren die gespeicherten Daten einem anderen Konto, weg damit.
      await offlineData?.ensureOwner(user.id);
      await offlineData?.store.writeJson(_userKey, user.toJson());
    } catch (e) {
      print('Lokale Daten nicht vorbereitbar: $e');
    }
    if (isClosed) return;

    final current = state;
    final unchanged = current is Authenticated &&
        current.user.id == user.id &&
        current.user.email == user.email;
    if (!unchanged) emit(Authenticated(user: user));
  }

  Future<void> _refreshUser() async {
    final remote = await userRepository.getUser();
    if (remote == null || isClosed) return;
    // Nur wenn die Session noch laeuft (sie kann inzwischen abgelaufen sein).
    if (state is Authenticated) await _startSession(remote);
  }

  @override
  Future<void> close() {
    _expirySub.cancel();
    return super.close();
  }
}
