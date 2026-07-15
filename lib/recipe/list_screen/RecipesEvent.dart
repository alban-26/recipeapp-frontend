import '../domain/Recipe.dart';

abstract class RecipesEvent {}

class LoadRecipesEvent
    extends RecipesEvent {} // Nachdem dieses Event getriggert wird, gelangen wir in einen der unteren States

class LoadMoreRecipesEvent extends RecipesEvent {} // Nachladen beim Scrollen (Infinite Scroll)

class PullToRefreshEvent extends RecipesEvent {}

class AddRecipeEvent extends RecipesEvent {}

class RecipeDeleted extends RecipesEvent {
  final Recipe recipe;

  RecipeDeleted(this.recipe);
}

class SearchRecipesEvent extends RecipesEvent {
  final String query;
  SearchRecipesEvent(this.query);
}