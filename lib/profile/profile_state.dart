import '../common/form_submission_status.dart';
import '../user/User.dart';

class ProfileState {
  final User user;

  String get email => user.email;

  final FormSubmissionStatus formStatus;

  ProfileState({
    required User user,
    this.formStatus = const InitialFormStatus(),
  }) : user = user;

  ProfileState copyWith({User? user, FormSubmissionStatus? formStatus}) {
    return ProfileState(
        user: user ?? this.user, formStatus: formStatus ?? this.formStatus);
  }
}
