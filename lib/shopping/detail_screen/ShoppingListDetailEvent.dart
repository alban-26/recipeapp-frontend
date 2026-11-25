
import '../domain/ShoppingItem.dart';
import '../domain/ShoppingList.dart';

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

/// Die Liste bekommt einen neuen Namen.
class RenameShoppingListEvent extends ShoppingListDetailEvent {
  final String title;

  RenameShoppingListEvent(this.title);
}


class ToggleShoppingListItemEvent extends ShoppingListDetailEvent {
  final ShoppingItem item;
  ToggleShoppingListItemEvent(this.item);
}

/// Ein bestehender Eintrag wurde bearbeitet (Name, Menge, Einheit).
class EditShoppingListItemEvent extends ShoppingListDetailEvent {
  final ShoppingItem item;
  EditShoppingListItemEvent(this.item);
}

class DeleteShoppingListItemEvent extends ShoppingListDetailEvent {
  final ShoppingItem item;
  final int shoppingListId;
  DeleteShoppingListItemEvent(this.item, this.shoppingListId);
}

/// [fromIndex] und [toIndex] sind Positionen in der Reihenfolge, wie sie auf
/// dem Bildschirm steht (offene Eintraege zuerst, abgehakte darunter).
class ReorderShoppingListItemsEvent extends ShoppingListDetailEvent {
  final int fromIndex;
  final int toIndex;

  ReorderShoppingListItemsEvent({
    required this.fromIndex,
    required this.toIndex,
  });
}

class ReorderByCommonEvent extends ShoppingListDetailEvent {

}

/// Intern: die lokalen Daten haben sich im Hintergrund geaendert
/// (Synchronisierung nach einer Offline-Phase).
class ShoppingListSyncedEvent extends ShoppingListDetailEvent {}
