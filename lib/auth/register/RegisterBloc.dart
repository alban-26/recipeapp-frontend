import 'dart:async';

import 'package:bloc/bloc.dart';

import '../AuthRepository.dart';
import '../navigation/AuthCubit.dart';
import 'RegisterEvent.dart';
import 'RegisterState.dart';

class RegisterBloc extends Bloc<RegisterEvent, RegisterState> {
  final AuthRepository authRepository;
  final AuthCubit navigationCubit;

  RegisterBloc({
    required this.authRepository,
    required this.navigationCubit,
  }) : super(const RegisterState()) {
    on<RegisterEmailChanged>(_onEmailChanged);
    on<RegisterPasswordChanged>(_onPasswordChanged);
    on<RegisterConfirmPasswordChanged>(_onConfirmPasswordChanged);
    on<RegisterSubmitted>(_onSubmitted);
  }

  void _onEmailChanged(
      RegisterEmailChanged event, Emitter<RegisterState> emit) {
    emit(state.copyWith(email: event.email));
  }

  void _onPasswordChanged(
      RegisterPasswordChanged event, Emitter<RegisterState> emit) {
    emit(state.copyWith(password: event.password));
  }

  void _onConfirmPasswordChanged(
      RegisterConfirmPasswordChanged event, Emitter<RegisterState> emit) {
    emit(state.copyWith(confirmPassword: event.confirmPassword));
  }

  Future<void> _onSubmitted(
      RegisterSubmitted event, Emitter<RegisterState> emit) async {
    if (state.status == RegisterStatus.loading) return;

    if (state.password != state.confirmPassword) {
      emit(state.copyWith(
        status: RegisterStatus.failure,
        error: "Passwörter nicht identisch!",
      ));
      return;
    }

    emit(state.copyWith(
      status: RegisterStatus.loading,
      error: null,
    ));

    try {
      await authRepository.register(
        state.email,
        state.password,
      );

      emit(state.copyWith(status: RegisterStatus.success));
      navigationCubit.showConfirm();

    } catch (e) {
      emit(state.copyWith(
        status: RegisterStatus.failure,
        error: e.toString(),
      ));
    }
  }

}
