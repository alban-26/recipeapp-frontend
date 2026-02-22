import '../domain/ShoppingList.dart';

abstract class ShoppingListsDetailState {}

class LoadedShoppingListDetailState extends ShoppingListsDetailState {
  final ShoppingList shoppingList;
  final Map<String, List<String>> allIngredients;

  LoadedShoppingListDetailState({
    required this.shoppingList,
    this.allIngredients = const {},
  });

  LoadedShoppingListDetailState copyWith({
    ShoppingList? shoppingList,
    Map<String, List<String>>? allIngredients,
  }) {
    return LoadedShoppingListDetailState(
      shoppingList: shoppingList ?? this.shoppingList,
      allIngredients: allIngredients ?? this.allIngredients,
    );
  }
}
