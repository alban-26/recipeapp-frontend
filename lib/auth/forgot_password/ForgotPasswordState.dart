import 'package:equatable/equatable.dart';

enum ForgotPasswordStatus { initial, loading, success, failure }

class ForgotPasswordState {
  final String email;
  final ForgotPasswordStatus status;
  final String? error;

  ForgotPasswordState({
    this.email = '',
    this.status = ForgotPasswordStatus.initial,
    this.error,
  });

  ForgotPasswordState copyWith({
    String? email,
    ForgotPasswordStatus? status,
    String? error,
  }) {
    return ForgotPasswordState(
      email: email ?? this.email,
      status: status ?? this.status,
      error: error,
    );
  }
}
