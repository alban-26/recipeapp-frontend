import 'package:flutter_bloc/flutter_bloc.dart';

import '../ShoppingListRepository.dart';
import '../navigation/ShoppingListNavigatorCubit.dart';
import 'ShoppingListEvent.dart';
import 'ShoppingListState.dart';

class ShoppingListBloc extends Bloc<ShoppingListEvent, ShoppingListState> {
  final ShoppingListRepository dataRepo;
  final ShoppingNavigatorCubit recipeNavigatorCubit;

  ShoppingListBloc({required this.dataRepo, required this.recipeNavigatorCubit}) : super(LoadingShoppingListState()) {
    on<LoadShoppingListEvent>((event, emit) async {
      emit(LoadingShoppingListState());
      try {
        final shoppingLists = await dataRepo.fetchShoppingLists();
        emit(LoadedShoppingListState(shoppingLists: shoppingLists));
      } on Error catch (exception) {
        emit(FailedToLoadShoppingListState(error: exception));
      }
    });
    on<PullToRefreshEvent>((event, emit) async {
      try {
        final shoppingLists = await dataRepo.fetchShoppingLists();
        emit(LoadedShoppingListState(shoppingLists: shoppingLists));
      } on Error catch (exception) {
        emit(FailedToLoadShoppingListState(error: exception));
      }
    });
    on<ShoppingListAdded>((event, emit) async {
      try {
        int insertedId = await dataRepo.addShoppingList(event.shoppingList);
        final shoppingLists = await dataRepo.fetchShoppingLists();
        emit(LoadedShoppingListState(shoppingLists: shoppingLists));
        recipeNavigatorCubit.showShoppingListDetail(event.shoppingList.copyWith(id: insertedId));

      } on Error catch (exception) {
        emit(FailedToLoadShoppingListState(error: exception));
      }
    });
    on<ShoppingListDeleted>((event, emit) async {
      try {
        await dataRepo.removeShoppingList(event.shoppingList.id);
        final shoppingLists = await dataRepo.fetchShoppingLists();
        emit(LoadedShoppingListState(shoppingLists: shoppingLists));
      } on Error catch (exception) {
        emit(FailedToLoadShoppingListState(error: exception));
      }
    });
  }
}
