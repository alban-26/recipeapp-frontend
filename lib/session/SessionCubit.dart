// Updated SessionCubit with Keycloak integration
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/user/UserRepository.dart';

import '../auth/AuthRepository.dart';
import '../user/User.dart';
import 'SessionState.dart';

class SessionCubit extends Cubit<SessionState> {
  final AuthRepository authRepo;
  final UserRepository userRepository;

  User get user => (state as Authenticated).user;

  SessionCubit({required this.authRepo, required this.userRepository})
      : super(UnknownSessionState()) {
    attemptAutoLogin();
  }

  Future<void> attemptAutoLogin() async {
    try {
      final tokens = await authRepo.getStoredTokens();

      if (tokens != null) {

        final user = await userRepository.getUser();
        if (user != null) {
          emit(Authenticated(user: user));
        } else {
          emit(Unauthenticated());
        }
      } else {

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
      await authRepo.register(
          user.email, password);
      emit(Registered());
    } catch (e) {
      emit(AuthErrorState(errorMessage: ''));
    }
  }

  void logout() async {
    await authRepo.logout();
    emit(Unauthenticated());
  }
}
