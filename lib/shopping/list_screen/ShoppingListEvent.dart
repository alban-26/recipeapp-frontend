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
