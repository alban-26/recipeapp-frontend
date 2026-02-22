import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

abstract class ProfileEvent {}

class ChangeAvatarRequest extends ProfileEvent {}

class OpenImagePicker extends ProfileEvent {
  final ImageSource imageSource;

  OpenImagePicker({required this.imageSource});
}

class ProvideImagePath extends ProfileEvent {
  final Uint8List imagePath;

  ProvideImagePath({required this.imagePath});
}

class LogoutEvent extends ProfileEvent {}

class DeleteAccountEvent extends ProfileEvent {}

class SaveProfileChanges extends ProfileEvent {}
