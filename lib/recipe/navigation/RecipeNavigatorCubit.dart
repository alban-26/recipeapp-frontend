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

  RecipeCreateState({required this.recipe});
}

class RecipeNavigatorCubit extends Cubit<RecipeNavigatorState> {
  final RecipeRepository dataRepo;

  RecipeNavigatorCubit({required this.dataRepo}) : super(RecipeListState());

  void showRecipeDetail(Recipe recipe) =>
      emit(RecipeDetailState(recipe: recipe));

  void showRecipes() => emit(RecipeListState());

  void showCreateRecipe() {
    emit(RecipeCreateState(
        recipe: Recipe(
            id: 0,
            name: '',
            cookingInstructions: [],
            recipeIngredients: [],
            portions: 4,
            duration: Duration.zero,
            image: null,
        tags: [])));
  }

  void updateRecipe(Recipe recipe) {
    emit(RecipeCreateState(recipe: recipe));
  }

  void cancelCreateRecipe() {
    emit(RecipeListState());
  }
}
