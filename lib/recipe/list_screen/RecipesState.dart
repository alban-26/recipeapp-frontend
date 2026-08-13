import '../domain/Recipe.dart';

abstract class RecipesState {}

class RecipesInitialState extends RecipesState {}

class LoadingRecipesState extends RecipesState {}

class LoadedRecipesState extends RecipesState {
  final List<Recipe> recipes;
  final int currentPage;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String searchQuery;
  final List<String> tags;        // NEU
  final List<String> availableTags;

  LoadedRecipesState({
    required this.recipes,
    this.currentPage = 0,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.searchQuery = '',
    this.tags = const [],             // NE
    this.availableTags = const [],     // NEU
  });

  LoadedRecipesState copyWith({
    List<Recipe>? recipes,
    int? currentPage,
    bool? hasReachedMax,
    bool? isLoadingMore,
    List<String>? tags,
    List<String>? availableTags,       // NEU
    String? searchQuery,
  }) {
    return LoadedRecipesState(
      recipes: recipes ?? this.recipes,
      currentPage: currentPage ?? this.currentPage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      tags: tags ?? this.tags,     // NEU
      availableTags: availableTags ?? this.availableTags,   // NEU
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class FailedToLoadRecipesState extends RecipesState {
  final Object error;
  FailedToLoadRecipesState({required this.error});
}


class CreateRecipesState extends RecipesState {}