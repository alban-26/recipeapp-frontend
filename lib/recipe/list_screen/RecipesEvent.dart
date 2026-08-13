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
  final List<String> tags;
  SearchRecipesEvent(this.query, {this.tags = const []});
}

/// 🏷 Lädt die vom User verwendeten Tags für die Filter-Auswahl.
class LoadTagsEvent extends RecipesEvent {}

/// 🔖 Setzt den aktiven Tag-Filter und lädt die Liste neu.
class FilterByTagsEvent extends RecipesEvent {
  final List<String> tags;
  FilterByTagsEvent(this.tags);
}