import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/recipe/RecipeRepository.dart';

import 'RecipesEvent.dart';
import 'RecipesState.dart';

class RecipesBloc extends Bloc<RecipesEvent, RecipesState> {
  final RecipeRepository dataRepo;
  static const int _pageSize = 20;

  RecipesBloc({required this.dataRepo}) : super(LoadingRecipesState()) {

    /// 🔄 Initial Load
    on<LoadRecipesEvent>((event, emit) async {
      emit(LoadingRecipesState());
      try {
        final page = await dataRepo.fetchRecipes(page: 0, size: _pageSize);
        emit(
          LoadedRecipesState(
            allRecipes: page.content,
            recipes: page.content,
            currentPage: page.page,
            hasReachedMax: page.last,
          ),
        );
      } on Error catch (exception) {
        emit(FailedToLoadRecipesState(error: exception));
      }
    });

    /// ⬇️ Load More (Infinite Scroll)
    on<LoadMoreRecipesEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! LoadedRecipesState) return;
      if (currentState.hasReachedMax || currentState.isLoadingMore) return;

      emit(currentState.copyWith(isLoadingMore: true));

      try {
        final nextPage = currentState.currentPage + 1;
        final page = await dataRepo.fetchRecipes(page: nextPage, size: _pageSize);

        final updatedAll = List.of(currentState.allRecipes)..addAll(page.content);

        final filtered = currentState.searchQuery.isEmpty
            ? updatedAll
            : updatedAll
            .where((recipe) => recipe.name
            .toLowerCase()
            .contains(currentState.searchQuery.toLowerCase()))
            .toList();

        emit(
          currentState.copyWith(
            allRecipes: updatedAll,
            recipes: filtered,
            currentPage: page.page,
            hasReachedMax: page.last,
            isLoadingMore: false,
          ),
        );
      } on Error catch (_) {
        emit(currentState.copyWith(isLoadingMore: false));
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

        emit(currentState.copyWith(recipes: filtered, searchQuery: event.query));
      }
    });

    /// ⬇ Pull To Refresh
    on<PullToRefreshEvent>((event, emit) async {
      try {
        final page = await dataRepo.fetchRecipes(page: 0, size: _pageSize);
        emit(
          LoadedRecipesState(
            allRecipes: page.content,
            recipes: page.content,
            currentPage: page.page,
            hasReachedMax: page.last,
          ),
        );
      } on Error catch (exception) {
        emit(FailedToLoadRecipesState(error: exception));
      }
    });

    /// ➕ Add Recipe
    on<AddRecipeEvent>((event, emit) async {
      try {
        final page = await dataRepo.fetchRecipes(page: 0, size: _pageSize);
        emit(
          LoadedRecipesState(
            allRecipes: page.content,
            recipes: page.content,
            currentPage: page.page,
            hasReachedMax: page.last,
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
        final page = await dataRepo.fetchRecipes(page: 0, size: _pageSize);
        emit(
          LoadedRecipesState(
            allRecipes: page.content,
            recipes: page.content,
            currentPage: page.page,
            hasReachedMax: page.last,
          ),
        );
      } on Error catch (exception) {
        emit(FailedToLoadRecipesState(error: exception));
      }
    });
  }
}