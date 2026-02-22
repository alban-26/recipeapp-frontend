
import '../domain/ShoppingItem.dart';
import '../domain/ShoppingList.dart';
import '../domain/Unit.dart';

abstract class ShoppingListDetailEvent {}

class LoadShoppingListDetailEvent extends ShoppingListDetailEvent {}

class RefreshShoppingListDetailEvent extends ShoppingListDetailEvent {}

class LoadIngredientsRequested extends ShoppingListDetailEvent {}

class AddShoppingListItemEvent extends ShoppingListDetailEvent {
  final ShoppingItem item;
  final int shoppingListId;
  AddShoppingListItemEvent(this.item, this.shoppingListId);
}

class UpdateShoppingListEvent extends ShoppingListDetailEvent {
  final ShoppingList shoppingList;

  UpdateShoppingListEvent(this.shoppingList);
}


class ToggleShoppingListItemEvent extends ShoppingListDetailEvent {
  final ShoppingItem item;
  ToggleShoppingListItemEvent(this.item);
}

class DeleteShoppingListItemEvent extends ShoppingListDetailEvent {
  final ShoppingItem item;
  final int shoppingListId;
  DeleteShoppingListItemEvent(this.item, this.shoppingListId);
}

class ReorderShoppingListItemsEvent extends ShoppingListDetailEvent {
  final int fromIndex;
  final int toIndex;

  ReorderShoppingListItemsEvent({
    required this.fromIndex,
    required this.toIndex,
  });
}

