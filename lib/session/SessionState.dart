import '../user/User.dart';

abstract class SessionState {}

class UnknownSessionState extends SessionState {}

class Unauthenticated extends SessionState {}

class Registered extends SessionState {}

class Authenticated extends SessionState {
  final User user;

  Authenticated({required this.user});
}

class LoadingSessionState extends SessionState {}

class ErrorSessionState extends SessionState {
  final String errorMessage;

  ErrorSessionState({required this.errorMessage});
}

class LoggedOutState extends SessionState {}

class AuthErrorState extends SessionState {
  final String errorMessage;

  AuthErrorState({required this.errorMessage});
}
