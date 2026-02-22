import 'package:bloc/bloc.dart';
import 'package:recipeapp_frontend/profile/profile_event.dart';
import 'package:recipeapp_frontend/profile/profile_state.dart';

import '../StorageRepository.dart';
import '../auth/AuthRepository.dart';
import '../user/User.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final StorageRepository storageRepo;
  final AuthRepository authRepo;

  ProfileBloc(
      {required this.storageRepo, required this.authRepo, required User user})
      : super(ProfileState(user: user)) {
    on<SaveProfileChanges>((event, emit) async {
    });
    on<LogoutEvent>((event, emit) async {
      try {
        await authRepo.logout();
      } on Exception catch (e) {
        print("Logout fehlgeschlagen");
        print(e);
      }
    });
  }
}
