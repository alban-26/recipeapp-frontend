import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/user/UserRepository.dart';

import '../api/TokenStore.dart';
import '../auth/AuthRepository.dart';
import '../user/User.dart';
import 'SessionState.dart';

class SessionCubit extends Cubit<SessionState> {
  final AuthRepository authRepo;
  final UserRepository userRepository;
  final TokenStore tokenStore;

  late final StreamSubscription<void> _expirySub;

  User get user => (state as Authenticated).user;

  SessionCubit({
    required this.authRepo,
    required this.userRepository,
    required this.tokenStore,
  }) : super(UnknownSessionState()) {
    // Wenn der Refresh Token serverseitig endgueltig abgelehnt wurde, meldet
    // der TokenStore das hier und die App springt sofort zum Login.
    _expirySub = tokenStore.onSessionExpired.listen((_) {
      if (state is! Unauthenticated) emit(Unauthenticated());
    });

    attemptAutoLogin();
  }

  Future<void> attemptAutoLogin() async {
    try {
      if (!await authRepo.hasSession()) {
        emit(Unauthenticated());
        return;
      }

      final user = await userRepository.getUser();
      if (user != null) {
        emit(Authenticated(user: user));
      } else {
        // Kann auch ein reiner Netzwerkfehler sein. Die Tokens bleiben in
        // jedem Fall erhalten - beim naechsten Start mit Verbindung greift
        // der Auto-Login wieder.
        // TODO Schritt 7: eigener Offline-State statt Login-Screen.
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(Unauthenticated());
    }
  }

  void showSession() async {
    try {
      final user = await userRepository.getUser();
      if (user != null) {
        emit(Authenticated(user: user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthErrorState(errorMessage: ''));
    }
  }

  Future<void> login(String email, String password) async {
    try {
      await authRepo.login(email, password);
      final user = await userRepository.getUser();
      if (user != null) {
        emit(Authenticated(user: user));
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
    emit(Unauthenticated());
  }

  @override
  Future<void> close() {
    _expirySub.cancel();
    return super.close();
  }
}
