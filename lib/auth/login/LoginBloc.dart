import 'package:flutter_bloc/flutter_bloc.dart';

import '../AuthRepository.dart';
import '../navigation/AuthCubit.dart';
import 'LoginEvent.dart';
import 'LoginState.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AuthRepository authRepository;
  final AuthCubit navigationCubit;

  LoginBloc({
    required this.authRepository,
    required this.navigationCubit,
  }) : super(const LoginState()) {
    on<LoginEmailChanged>(_onEmailChanged);
    on<LoginPasswordChanged>(_onPasswordChanged);
    on<LoginSubmitted>(_onSubmitted);
  }

  void _onEmailChanged(LoginEmailChanged event, Emitter<LoginState> emit) {
    emit(state.copyWith(email: event.email));
  }

  void _onPasswordChanged(
      LoginPasswordChanged event, Emitter<LoginState> emit) {
    emit(state.copyWith(password: event.password));
  }

  Future<void> _onSubmitted(
      LoginSubmitted event, Emitter<LoginState> emit) async {
    if (state.status == LoginStatus.loading) return;

    emit(state.copyWith(status: LoginStatus.loading));

    try {
      await authRepository.login(state.email, state.password);
      emit(state.copyWith(status: LoginStatus.success));
      navigationCubit.launchSession();
    } catch (e) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        error: e.toString(),
      ));
    }
  }
}
