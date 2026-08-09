import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:recipeapp_frontend/recipe/domain/CookingInstruction.dart';
import 'package:recipeapp_frontend/recipe/domain/RecipeIngredient.dart';

abstract class CreateRecipeEvent {}

class ChangeRecipeImageRequest extends CreateRecipeEvent {}

class RecipeNameChanged extends CreateRecipeEvent {
  final String recipeName;

  RecipeNameChanged({required this.recipeName});
}

class LoadIngredientsRequested extends CreateRecipeEvent {}


class DurationChanged extends CreateRecipeEvent {
  final int duration;

  DurationChanged({required this.duration});
}

class IncrementPortions extends CreateRecipeEvent {}

class DecrementPortions extends CreateRecipeEvent {}

class CancelImageSelection extends CreateRecipeEvent {}

class OpenImagePicker extends CreateRecipeEvent {
  final ImageSource imageSource;

  OpenImagePicker({required this.imageSource});
}

class CurrentImageDeleted extends CreateRecipeEvent {}

class ProvideImagePath extends CreateRecipeEvent {
  final Uint8List? imagePath;

  ProvideImagePath({required this.imagePath});
}

class ScanRecipeStarted extends CreateRecipeEvent {}
class ScanRecipeFinished extends CreateRecipeEvent {}

class SaveCreateRecipeChanges extends CreateRecipeEvent {}

class CookingInstructionChanged extends CreateRecipeEvent {
  final int index;
  final CookingInstruction cookingInstruction;

  CookingInstructionChanged(
      {required this.index, required this.cookingInstruction});
}

class InstructionIngredientToggled extends CreateRecipeEvent {
  final int instructionIndex;
  final RecipeIngredient ingredient;

  InstructionIngredientToggled({
    required this.instructionIndex,
    required this.ingredient,
  });
}

class IngredientChanged extends CreateRecipeEvent {
  final int index;
  final String ingredient;
  final String productCategory;

  IngredientChanged({required this.index, required this.ingredient, required this.productCategory});
}

class IngredientInitialized extends CreateRecipeEvent {
  final List<RecipeIngredient> ingredients;

  IngredientInitialized({required this.ingredients});
}

class CookingInstructionsInitialized extends CreateRecipeEvent {
  final List<CookingInstruction> cookingInstructions;

  CookingInstructionsInitialized({required this.cookingInstructions});
}

class QuantityChanged extends CreateRecipeEvent {
  final int index;
  final double quantity;

  QuantityChanged({required this.index, required this.quantity});
}

class UnitChanged extends CreateRecipeEvent {
  final int index;
  final String unit;

  UnitChanged({required this.index, required this.unit});
}

class CookingInstructionAdded extends CreateRecipeEvent {}

class IngredientAdded extends CreateRecipeEvent {}

class DeleteIngredient extends CreateRecipeEvent {
  final int index;

  DeleteIngredient(this.index);
}

class CookingInstructionDeleted extends CreateRecipeEvent {
  final int index;

  CookingInstructionDeleted(this.index);
}

class RecipeScanned extends CreateRecipeEvent {
  final Map<String, dynamic> recipe;

  RecipeScanned(this.recipe);
}