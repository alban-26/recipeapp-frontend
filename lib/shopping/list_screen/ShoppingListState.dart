
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
  // Object statt Error: Netzwerkfehler (DioException) sind Exceptions und
  // wurden vorher gar nicht abgefangen - die Seite blieb beim Ladekreis haengen.
  Object error;

  FailedToLoadShoppingListState({required this.error});
}
