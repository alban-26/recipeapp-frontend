import '../domain/ShoppingList.dart';

abstract class ShoppingListEvent {}

class LoadShoppingListEvent extends ShoppingListEvent {}

class PullToRefreshEvent extends ShoppingListEvent {}

class ShoppingListAdded extends ShoppingListEvent {
  final ShoppingList shoppingList;
  ShoppingListAdded(this.shoppingList);
}

class ShoppingListDeleted extends ShoppingListEvent {
  final ShoppingList shoppingList;
  ShoppingListDeleted(this.shoppingList);
}

class ShoppingListRenamed extends ShoppingListEvent {
  final ShoppingList shoppingList;
  final String title;
  ShoppingListRenamed(this.shoppingList, this.title);
}

/// Intern: die lokalen Daten haben sich im Hintergrund geaendert
/// (Synchronisierung nach einer Offline-Phase).
class ShoppingListsSyncedEvent extends ShoppingListEvent {}
