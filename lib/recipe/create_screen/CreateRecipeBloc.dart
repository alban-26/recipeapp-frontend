import 'dart:io';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/cupertino.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:recipeapp_frontend/recipe/RecipeRepository.dart';
import 'package:recipeapp_frontend/recipe/domain/CookingInstruction.dart';
import 'package:recipeapp_frontend/recipe/domain/RecipeIngredient.dart';
import 'package:uuid/uuid.dart';

import '../../StorageRepository.dart';
import '../../common/form_submission_status.dart';
import '../domain/Recipe.dart';
import '../navigation/RecipeNavigatorCubit.dart';
import '../services/ingredients_service.dart';
import 'CreateRecipeEvent.dart';
import 'CreateRecipeState.dart';

class CreateRecipeBloc extends Bloc<CreateRecipeEvent, CreateRecipeState> {
  final RecipeRepository dataRepo;
  final StorageRepository storageRepo;
  final RecipeNavigatorCubit recipeNavigatorCubit;
  final _picker = ImagePicker();

  CreateRecipeBloc(
      {required this.dataRepo,
      required this.storageRepo,
      required this.recipeNavigatorCubit,
      required Recipe initialRecipe})
      : super(CreateRecipeState(recipe: initialRecipe)) {
    on<RecipeScanned>((event, emit) {

      final recipe = Recipe.fromLLMJson(event.recipe);

      emit(state.copyWith(recipe: recipe));
    });

    on<LoadIngredientsRequested>((event, emit) async {
      final Map<String, List<String>> ingredients = await IngredientsService.loadIngredients();
      final Map<String, List<String>> customIngredients = await dataRepo.loadIngredients();

      final merged = <String, List<String>>{...ingredients};
      for (final entry in customIngredients.entries) {
        merged.putIfAbsent(entry.key, () => []).addAll(entry.value);
      }

      emit(state.copyWith(allIngredients: merged));
    });
    add(LoadIngredientsRequested());

    on<ChangeRecipeImageRequest>((event, emit) async {
      emit(state.copyWith(imageSourceActionSheetIsVisible: true));
    });
    on<CancelImageSelection>((event, emit) async {
      emit(state.copyWith(imageSourceActionSheetIsVisible: false));
    });
    on<OpenImagePicker>((event, emit) async {
      emit(state.copyWith(imageSourceActionSheetIsVisible: false));
      state.imageToUpload = await _picker.pickImage(source: event.imageSource);

      if (state.imageToUpload == null) return;

      final imageFile = File(state.imageToUpload!.path);
      final maxSize = 450 * 1024; // 5MB
      Uint8List? imageData;

      try {
        final originalBytes = await imageFile.readAsBytes();
        img.Image? image = img.decodeImage(originalBytes);

        if (image == null) {
          emit(state.copyWith(imageError: 'Invalid image format'));
          return;
        }

        imageData = await compressImage(image, targetSize: maxSize);

        if (imageData == null) {
          emit(state.copyWith(
            imageError: 'Image could not be compressed to 5MB',
            imagePath: null,
            imageToUpload: null,
          ));
          return;
        }
        emit(state.copyWith(recipe: state.recipe.copyWith(image: imageData)));
        emit(state.copyWith(
          imagePath: imageData,
          imageChanged: true,
          imageError: null,
        ));
      } catch (e) {
        emit(state.copyWith(
          imageError: 'Error processing image: ${e.toString()}',
          imagePath: null,
          imageToUpload: null,
        ));
      }
    });
    on<CurrentImageDeleted>((event, emit) async {
      final updatedRecipe = state.recipe.copyWithoutImage();
      emit(state.copyWith(
        recipe: updatedRecipe,
        imageSourceActionSheetIsVisible: false,
      ));
    });

    on<ProvideImagePath>((event, emit) async {
      Recipe updatedRecipe = state.recipe.copyWith(image: event.imagePath);
      emit(state.copyWith(recipe: updatedRecipe));
    });
    on<IngredientAdded>((event, emit) async {
      final List<RecipeIngredient> updatedIngredients =
          List.from(state.recipe.recipeIngredients)
            ..add(RecipeIngredient(id: const Uuid().v4(), name: '', category: '', unit: '', quantity: 0));

      final Recipe updatedRecipe =
          state.recipe.copyWith(recipeIngredients: updatedIngredients);

      emit(state.copyWith(
        recipeIngredients: updatedIngredients,
        recipe: updatedRecipe,
      ));
    });

    on<IngredientChanged>((event, emit) async {
      final List<RecipeIngredient> updatedIngredients =
          List<RecipeIngredient>.from(state.recipe.recipeIngredients);
      updatedIngredients[event.index] =
          updatedIngredients[event.index].copyWith(name: event.ingredient, productCategory: event.productCategory);
      final Recipe updatedRecipe =
          state.recipe.copyWith(recipeIngredients: updatedIngredients);
      emit(state.copyWith(recipe: updatedRecipe));
    });
    on<DeleteIngredient>((event, emit) async {
      final updatedIngredients =
          List<RecipeIngredient>.from(state.recipe.recipeIngredients)
            ..removeAt(event.index);

      final updatedRecipe = state.recipe.copyWith(
        recipeIngredients: updatedIngredients,
      );

      emit(state.copyWith(
        recipe: updatedRecipe,
      ));
    });
    on<CookingInstructionAdded>((event, emit) async {
      final updatedInstructions =
          List<CookingInstruction>.from(state.recipe.cookingInstructions)
            ..add(
              CookingInstruction(
                instruction: '',
                recipeIngredients: [],
              ),
            );

      final updatedRecipe = state.recipe.copyWith(
        cookingInstructions: updatedInstructions,
      );

      emit(state.copyWith(
        recipe: updatedRecipe,
      ));
    });
    on<CookingInstructionChanged>((event, emit) async {
      final List<CookingInstruction> updatedInstructions =
          List<CookingInstruction>.from(state.recipe.cookingInstructions);
      updatedInstructions[event.index] = event.cookingInstruction;

      final Recipe updatedRecipe =
          state.recipe.copyWith(cookingInstructions: updatedInstructions);
      emit(state.copyWith(
        recipe: updatedRecipe,
      ));
    });
    on<CookingInstructionDeleted>((event, emit) async {
      final updatedInstructions =
          List<CookingInstruction>.from(state.recipe.cookingInstructions)
            ..removeAt(event.index);

      final updatedRecipe = state.recipe.copyWith(
        cookingInstructions: updatedInstructions,
      );

      emit(state.copyWith(
        recipe: updatedRecipe,
      ));
    });

    on<QuantityChanged>((event, emit) async {
      final updatedIngredients =
          List<RecipeIngredient>.from(state.recipe.recipeIngredients);
      updatedIngredients[event.index] =
          updatedIngredients[event.index].copyWith(quantity: event.quantity);
      final Recipe updatedRecipe =
          state.recipe.copyWith(recipeIngredients: updatedIngredients);
      emit(state.copyWith(recipe: updatedRecipe));
    });

    on<UnitChanged>((event, emit) async {
      final List<RecipeIngredient> updatedIngredients =
          List<RecipeIngredient>.from(state.recipe.recipeIngredients);
      updatedIngredients[event.index] =
          updatedIngredients[event.index].copyWith(unit: event.unit);
      final Recipe updatedRecipe =
          state.recipe.copyWith(recipeIngredients: updatedIngredients);
      emit(state.copyWith(recipe: updatedRecipe));
    });

    on<RecipeNameChanged>((event, emit) async {
      final Recipe updatedRecipe =
          state.recipe.copyWith(name: event.recipeName);
      emit(state.copyWith(recipe: updatedRecipe));
    });
    on<DurationChanged>((event, emit) async {
      final Recipe updatedRecipe =
          state.recipe.copyWith(duration: Duration(minutes: event.duration));
      emit(state.copyWith(recipe: updatedRecipe));
    });
    on<IncrementPortions>((event, emit) async {
      final Recipe updatedRecipe =
          state.recipe.copyWith(portions: state.recipe.portions + 1);
      emit(state.copyWith(recipe: updatedRecipe));
    });
    on<DecrementPortions>((event, emit) async {
      final Recipe updatedRecipe =
          state.recipe.copyWith(portions: state.recipe.portions - 1);
      emit(state.copyWith(recipe: updatedRecipe));
    });

    on<SaveCreateRecipeChanges>((event, emit) async {

      if (state.recipe.id == 0) {
        int insertedId = await dataRepo.addRecipe(state.recipe);

        storageRepo.uploadImage(
          state.imagePath!, // Uint8List
          insertedId.toString(),
          "/recipes/$insertedId/image",
        );


        emit(state.copyWith(formStatus: SubmissionSuccess()));
      } else {

        Recipe recipe = await dataRepo.updateRecipe(state.recipe);

        if (state.isImageChanged) {
          storageRepo.uploadImage(state.imagePath!,
              recipe.id.toString(), "/recipes/${recipe.id}/image");
        }

        emit(state.copyWith(formStatus: SubmissionSuccess()));
      }


    });
  }

  Future<Uint8List?> compressImage(
      img.Image image, {
        int targetSize = 450 * 1024, // 🎯 450 KB
      }) async {
    const int maxEdge = 1600;

    img.Image current = image;
    if (current.width > maxEdge || current.height > maxEdge) {
      current = img.copyResize(
        current,
        width: current.width >= current.height ? maxEdge : null,
        height: current.height > current.width ? maxEdge : null,
        maintainAspect: true,
      );
    }

    for (int quality = 75; quality >= 45; quality -= 5) {
      final bytes = Uint8List.fromList(
        img.encodeJpg(current, quality: quality),
      );

      if (bytes.length <= targetSize) {
        return bytes;
      }
    }

    for (double scale = 0.9; scale >= 0.6; scale -= 0.1) {
      final resized = img.copyResize(
        current,
        width: (current.width * scale).round(),
        height: (current.height * scale).round(),
        maintainAspect: true,
      );

      final bytes = Uint8List.fromList(
        img.encodeJpg(resized, quality: 60),
      );

      if (bytes.length <= targetSize) {
        return bytes;
      }
    }

    return null;
  }



}

// Function to generate a new GUID.
String generateGUID() {
  final uuid = Uuid();
  return uuid.v4();
}
