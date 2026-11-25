import 'package:flutter_bloc/flutter_bloc.dart';

import '../RecipeRepository.dart';
import '../domain/Recipe.dart';

abstract class RecipeNavigatorState {}

class RecipeListState extends RecipeNavigatorState {}

class RecipeNavigatorInitial extends RecipeNavigatorState {}

class RecipeDetailState extends RecipeNavigatorState {
  final Recipe recipe;

  RecipeDetailState({required this.recipe});

  RecipeDetailState copyWith({
    required Recipe recipe,
  }) {
    return RecipeDetailState(
      recipe: recipe,
    );
  }
}

class RecipeCreateState extends RecipeNavigatorState {
  final Recipe recipe;

  /// Geteilter Text mit Link, der beim Oeffnen importiert wird.
  final String? importText;

  /// Jede Import-Anfrage bekommt eine eigene Seite, auch wenn schon ein
  /// Formular offen ist.
  final Object? importRequest;

  RecipeCreateState({required this.recipe, this.importText})
      : importRequest = importText == null ? null : Object();
}

class RecipeNavigatorCubit extends Cubit<RecipeNavigatorState> {
  final RecipeRepository dataRepo;

  RecipeNavigatorCubit({required this.dataRepo}) : super(RecipeListState());

  void showRecipeDetail(Recipe recipe) =>
      emit(RecipeDetailState(recipe: recipe));

  void showRecipes() => emit(RecipeListState());

  void showCreateRecipe() {
    emit(RecipeCreateState(recipe: _emptyRecipe()));
  }

  /// Neues Rezept aus einem geteilten Link.
  void showImportRecipe(String sharedText) {
    emit(RecipeCreateState(recipe: _emptyRecipe(), importText: sharedText));
  }

  static Recipe _emptyRecipe() => Recipe(
      id: 0,
      name: '',
      cookingInstructions: [],
      recipeIngredients: [],
      portions: 4,
      duration: Duration.zero,
      image: null,
      tags: []);

  void updateRecipe(Recipe recipe) {
    emit(RecipeCreateState(recipe: recipe));
  }

  void cancelCreateRecipe() {
    emit(RecipeListState());
  }
}
