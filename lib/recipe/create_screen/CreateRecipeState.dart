import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipeapp_frontend/recipe/domain/CookingInstruction.dart';
import 'package:recipeapp_frontend/recipe/domain/RecipeIngredient.dart';

import '../../common/form_submission_status.dart';
import '../domain/Recipe.dart';

class CreateRecipeState {
  XFile? imageToUpload;

  Uint8List? imagePath;

  bool isImageChanged;

  bool imageSourceActionSheetIsVisible;

  bool get isValidRecipeName => recipe.name.length > 1;
  final FormSubmissionStatus formStatus;

  String? imageError;

  final Recipe recipe;

  final Map<String, List<String>> allIngredients;
  final bool isScanning;

  CreateRecipeState({
    this.imageToUpload,
    this.isImageChanged = false,
    this.imagePath,
    List<RecipeIngredient>? recipeIngredients,
    List<CookingInstruction>? cookingInstructions,
    this.formStatus = const InitialFormStatus(),
    imageSourceActionSheetIsVisible = false,
    imageError = '',
    required this.recipe,
    this.allIngredients = const {},
    this.isScanning = false
  }) : imageSourceActionSheetIsVisible = imageSourceActionSheetIsVisible;

  CreateRecipeState copyWith({
    int? id,
    String? recipeName,
    int? duration,
    int? portions,
    List<RecipeIngredient>? recipeIngredients,
    List<CookingInstruction>? cookingInstructions,
    Uint8List? imagePath,
    XFile? imageToUpload,
    FormSubmissionStatus? formStatus,
    bool? imageSourceActionSheetIsVisible,
    String? imageError,
    bool? isImageInitialized,
    bool? imageChanged,
    Recipe? recipe,
    Map<String, List<String>>? allIngredients,
    bool? isScanning
  }) {
    return CreateRecipeState(
      imageToUpload: imageToUpload ?? this.imageToUpload,
      imagePath: imagePath ?? this.imagePath,
      isImageChanged: imageChanged ?? this.isImageChanged,
      formStatus: formStatus ?? this.formStatus,
      imageSourceActionSheetIsVisible: imageSourceActionSheetIsVisible ??
          this.imageSourceActionSheetIsVisible,
      imageError: imageError ?? this.imageError,
      recipe: recipe ?? this.recipe,
      allIngredients: allIngredients ?? this.allIngredients ?? const {},
      isScanning: isScanning ?? this.isScanning
    );
  }

  CreateRecipeState copyWithoutImagePath({
    int? id,
    String? recipeName,
    int? duration,
    int? portions,
    List<RecipeIngredient>? recipeIngredients,
    List<CookingInstruction>? cookingInstructions,
    Uint8List? imagePath,
    XFile? imageToUpload,
    FormSubmissionStatus? formStatus,
    bool? imageSourceActionSheetIsVisible,
    String? imageError,
    Map<String, List<String>>? allIngredients,
    bool? isScanning
  }) {
    return CreateRecipeState(
      imageToUpload: imageToUpload ?? this.imageToUpload,
      formStatus: formStatus ?? this.formStatus,
      imageSourceActionSheetIsVisible: imageSourceActionSheetIsVisible ??
          this.imageSourceActionSheetIsVisible,
      imageError: imageError ?? this.imageError,
      recipe: recipe,
      allIngredients: allIngredients ?? this.allIngredients,
        isScanning: isScanning ?? this.isScanning
    );
  }
}
