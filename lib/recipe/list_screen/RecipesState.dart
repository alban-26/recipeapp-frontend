import '../domain/Recipe.dart';

abstract class RecipesState {}

class RecipesInitialState extends RecipesState {}

class LoadingRecipesState extends RecipesState {}

class LoadedRecipesState extends RecipesState {
  final List<Recipe> allRecipes;
  final List<Recipe> recipes;
  final int currentPage;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String searchQuery;

  LoadedRecipesState({
    required this.allRecipes,
    required this.recipes,
    this.currentPage = 0,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.searchQuery = '',
  });

  LoadedRecipesState copyWith({
    List<Recipe>? allRecipes,
    List<Recipe>? recipes,
    int? currentPage,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? searchQuery,
  }) {
    return LoadedRecipesState(
      allRecipes: allRecipes ?? this.allRecipes,
      recipes: recipes ?? this.recipes,
      currentPage: currentPage ?? this.currentPage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}


class CreateRecipesState extends RecipesState {}

class FailedToLoadRecipesState extends RecipesState {
  Error error;

  FailedToLoadRecipesState({required this.error});
}