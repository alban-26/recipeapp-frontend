import '../domain/Recipe.dart';

abstract class RecipesState {}

class RecipesInitialState extends RecipesState {}

class LoadingRecipesState extends RecipesState {}

class LoadedRecipesState extends RecipesState {
  final List<Recipe> allRecipes;
  final List<Recipe> recipes;

  LoadedRecipesState({
    required this.allRecipes,
    required this.recipes,
  });

  LoadedRecipesState copyWith({
    List<Recipe>? allRecipes,
    List<Recipe>? recipes,
  }) {
    return LoadedRecipesState(
      allRecipes: allRecipes ?? this.allRecipes,
      recipes: recipes ?? this.recipes,
    );
  }
}


class CreateRecipesState extends RecipesState {}

class FailedToLoadRecipesState extends RecipesState {
  Error error;

  FailedToLoadRecipesState({required this.error});
}
