import 'package:bloc/bloc.dart';

import '../../session/SessionCubit.dart';

enum AuthState { login, register, confirm, forgotPassword }


class AuthCubit extends Cubit<AuthState> {
  final SessionCubit sessionCubit;

  AuthCubit({required this.sessionCubit})
      : super(AuthState.login);

  void showLogin() => emit(AuthState.login);

  void showSignUp() => emit(AuthState.register);

  void showConfirm() => emit(AuthState.confirm);

  void showForgotPassword() => emit(AuthState.forgotPassword);

  void launchSession() => sessionCubit.showSession();
}
