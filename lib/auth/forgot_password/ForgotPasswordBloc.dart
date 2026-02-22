import 'package:bloc/bloc.dart';

import '../AuthRepository.dart';
import 'ForgotPasswordEvent.dart';
import 'ForgotPasswordState.dart';

class ForgotPasswordBloc
    extends Bloc<ForgotPasswordEvent, ForgotPasswordState> {
  final AuthRepository authRepository;

  ForgotPasswordBloc({required this.authRepository})
      : super(ForgotPasswordState()) {
    on<ForgotPasswordEmailChanged>(_onEmailChanged);
    on<ForgotPasswordSubmitted>(_onSubmitted);
  }

  void _onEmailChanged(
      ForgotPasswordEmailChanged event, Emitter<ForgotPasswordState> emit) {
    emit(state.copyWith(email: event.email));
  }

  Future<void> _onSubmitted(
      ForgotPasswordSubmitted event,
      Emitter<ForgotPasswordState> emit,
      ) async {
    if (state.email.isEmpty) {
      emit(state.copyWith(
        status: ForgotPasswordStatus.failure,
        error: "Bitte gib deine Email ein",
      ));
      return;
    }


    emit(state.copyWith(
      status: ForgotPasswordStatus.loading,
      error: null,
    ));

    try {

      await authRepository.forgotPassword(state.email);


      emit(state.copyWith(
        status: ForgotPasswordStatus.success,
        error: null,
      ));
    } catch (e) {

      emit(state.copyWith(
        status: ForgotPasswordStatus.failure,
        error: e.toString(),
      ));
    }
  }


}
