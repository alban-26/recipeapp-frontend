import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/recipe/RecipeRepository.dart';

import 'RecipesEvent.dart';
import 'RecipesState.dart';

class RecipesBloc extends Bloc<RecipesEvent, RecipesState> {
  final RecipeRepository dataRepo;

  RecipesBloc({required this.dataRepo}) : super(LoadingRecipesState()) {

    /// 🔄 Initial Load
    on<LoadRecipesEvent>((event, emit) async {
      emit(LoadingRecipesState());
      try {
        final recipes = await dataRepo.fetchRecipes();
        emit(
          LoadedRecipesState(
            allRecipes: recipes,
            recipes: recipes,
          ),
        );
      } on Error catch (exception) {
        emit(FailedToLoadRecipesState(error: exception));
      }
    });

    /// 🔍 Search
    on<SearchRecipesEvent>((event, emit) {
      if (state is LoadedRecipesState) {
        final currentState = state as LoadedRecipesState;

        final filtered = currentState.allRecipes
            .where((recipe) =>
            recipe.name
                .toLowerCase()
                .contains(event.query.toLowerCase()))
            .toList();

        emit(currentState.copyWith(recipes: filtered));
      }
    });

    /// ⬇ Pull To Refresh
    on<PullToRefreshEvent>((event, emit) async {
      try {
        final recipes = await dataRepo.fetchRecipes();
        emit(
          LoadedRecipesState(
            allRecipes: recipes,
            recipes: recipes,
          ),
        );
      } on Error catch (exception) {
        emit(FailedToLoadRecipesState(error: exception));
      }
    });

    /// ➕ Add Recipe
    on<AddRecipeEvent>((event, emit) async {
      try {
        final recipes = await dataRepo.fetchRecipes();
        emit(
          LoadedRecipesState(
            allRecipes: recipes,
            recipes: recipes,
          ),
        );
      } on Error catch (exception) {
        emit(FailedToLoadRecipesState(error: exception));
      }
    });

    /// 🗑 Delete Recipe
    on<RecipeDeleted>((event, emit) async {
      try {
        await dataRepo.removeRecipe(event.recipe.id);
        final recipes = await dataRepo.fetchRecipes();
        emit(
          LoadedRecipesState(
            allRecipes: recipes,
            recipes: recipes,
          ),
        );
      } on Error catch (exception) {
        emit(FailedToLoadRecipesState(error: exception));
      }
    });
  }
}
