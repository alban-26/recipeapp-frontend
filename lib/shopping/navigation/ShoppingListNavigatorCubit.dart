import 'package:bloc/bloc.dart';

import '../ShoppingListRepository.dart';
import '../domain/ShoppingList.dart';


abstract class ShoppingNavigatorState {}

class ShoppingListCubitState extends ShoppingNavigatorState {}

class ShoppingNavigatorInitial extends ShoppingNavigatorState {}

class ShoppingListDetailState extends ShoppingNavigatorState {
  final ShoppingList shoppingList;

  ShoppingListDetailState({required this.shoppingList});

  ShoppingListDetailState copyWith({
    required ShoppingList shoppingList,
  }) {
    return ShoppingListDetailState(
      shoppingList: shoppingList,
    );
  }
}

class ShoppingListCreateState extends ShoppingNavigatorState {
  final ShoppingList shoppingList;

  ShoppingListCreateState({required this.shoppingList});
}

class ShoppingNavigatorCubit extends Cubit<ShoppingNavigatorState> {
  final ShoppingListRepository repository;

  ShoppingNavigatorCubit({required this.repository})
      : super(ShoppingListCubitState());

  void showShoppingListDetail(ShoppingList shoppingList) =>
      emit(ShoppingListDetailState(shoppingList: shoppingList));

  void showShoppingLists() => emit(ShoppingListCubitState());

  void showCreateShoppingList() {
    emit(ShoppingListCreateState(
      shoppingList: ShoppingList(
        id: 0,
        title: '',
        shoppingItems: [],
        createdAt: DateTime.now(),
      ),
    ));
  }

  void updateShoppingList(ShoppingList shoppingList) {
    if (state is ShoppingListCreateState) {
      emit(ShoppingListCreateState(shoppingList: shoppingList));
    } else if (state is ShoppingListDetailState) {
      emit(ShoppingListDetailState(shoppingList: shoppingList));
    }
  }

  void cancelCreateShoppingList() {
    emit(ShoppingListCubitState());
  }
}