
import '../domain/ShoppingList.dart';

abstract class ShoppingListState {}

class ShoppingListInitialState extends ShoppingListState {}

class LoadingShoppingListState extends ShoppingListState {}

class LoadedShoppingListState extends ShoppingListState {
  List<ShoppingList> shoppingLists;

  LoadedShoppingListState({required this.shoppingLists});
}

class CreateShoppingListState extends ShoppingListState {}

class FailedToLoadShoppingListState extends ShoppingListState {
  Error error;

  FailedToLoadShoppingListState({required this.error});
}
