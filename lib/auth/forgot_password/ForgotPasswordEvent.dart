import 'package:equatable/equatable.dart';

abstract class ForgotPasswordEvent {}

class ForgotPasswordEmailChanged extends ForgotPasswordEvent {
  final String email;
  ForgotPasswordEmailChanged(this.email);
}

class ForgotPasswordSubmitted extends ForgotPasswordEvent {}
