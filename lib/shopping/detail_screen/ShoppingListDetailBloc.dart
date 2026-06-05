import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/shopping/ShoppingListRepository.dart';
import '../../recipe/services/ingredients_service.dart';
import '../ReorderShoppingItemsRequest.dart';
import '../domain/ShoppingItem.dart';
import '../domain/ShoppingList.dart';
import 'ShoppingListDetailEvent.dart';
import 'ShoppingListDetailState.dart';

class ShoppingListDetailBloc
    extends Bloc<ShoppingListDetailEvent, ShoppingListsDetailState> {

  final ShoppingListRepository dataRepo;

  ShoppingListDetailBloc({required this.dataRepo, required ShoppingList initialList})
      : super(LoadedShoppingListDetailState(shoppingList: initialList)) {
    on<LoadShoppingListDetailEvent>((event, emit) {
      emit(state);
    });

    on<LoadIngredientsRequested>((event, emit) async {
      final ingredients = await IngredientsService.loadShoppingItems();
      emit((state as LoadedShoppingListDetailState)
          .copyWith(allIngredients: ingredients ?? {}));

    });
    add(LoadIngredientsRequested());

    on<RefreshShoppingListDetailEvent>((event, emit) async {
      final currentState = state;
      if (currentState is LoadedShoppingListDetailState) {
        try {
          final updatedList = await dataRepo.fetchShoppingList(
            currentState.shoppingList.id.toString(),
          );

          emit(
            LoadedShoppingListDetailState(shoppingList: updatedList),
          );
        } catch (e) {
          emit(currentState);
        }
      }
    });


    on<ReorderShoppingListItemsEvent>((event, emit) async {
      final currentState = state as LoadedShoppingListDetailState;
      final items = currentState.shoppingList.shoppingItems;

      if (event.fromIndex < 0 ||
          event.toIndex < 0 ||
          event.fromIndex >= items.length ||
          event.toIndex >= items.length ||
          event.fromIndex == event.toIndex) {
        return;
      }

      final reorderedItems = List<ShoppingItem>.from(items);
      final movedItem = reorderedItems.removeAt(event.fromIndex);
      reorderedItems.insert(event.toIndex, movedItem);

      final rerankedItems = List.generate(
        reorderedItems.length,
            (index) => reorderedItems[index].copyWith(rank: index),
      );

      emit(
        LoadedShoppingListDetailState(
          shoppingList: currentState.shoppingList.copyWith(
            shoppingItems: rerankedItems,
          ),
        ),
      );

      await dataRepo.reorderShoppingItem(
        currentState.shoppingList.id,
        ReorderShoppingItemsRequest(
          fromIndex: event.fromIndex,
          toIndex: event.toIndex,
        ),
      );
    });

    on<ReorderByCommonEvent>((event, emit) async {
      final currentState = state as LoadedShoppingListDetailState;

      await dataRepo.reorderByCommon(currentState.shoppingList.id);

      // aktualisierte Liste vom Server holen
      final updatedList = await dataRepo.fetchShoppingList(currentState.shoppingList.id.toString());

      emit(
        LoadedShoppingListDetailState(
          shoppingList: updatedList,
        ),
      );
    });


    on<AddShoppingListItemEvent>((event, emit) async {
      final currentState = state as LoadedShoppingListDetailState;
      int insertedId = await dataRepo.addShoppingItem(event.shoppingListId, event.item);

      final updatedItems = List<ShoppingItem>.from(
          currentState.shoppingList.shoppingItems)
        ..add(event.item.copyWith(id: insertedId));
      emit(currentState.copyWith(
        shoppingList: currentState.shoppingList.copyWith(
          shoppingItems: updatedItems,
        ),
      ));

    });

    on<ToggleShoppingListItemEvent>((event, emit) {
      final currentState = state as LoadedShoppingListDetailState;
      final updatedItems = currentState.shoppingList.shoppingItems
          .map((i) => i.id == event.item.id ? event.item : i)
          .toList();
      dataRepo.updateShoppingItem(
        currentState.shoppingList.id,
        event.item.id,
        event.item,
      );
      emit(LoadedShoppingListDetailState(
        shoppingList: currentState.shoppingList.copyWith(
          shoppingItems: updatedItems,
        ),
      ));
    });

    on<UpdateShoppingListEvent>((event, emit) async {
      final currentState = state;
      if (currentState is LoadedShoppingListDetailState) {
        await dataRepo.updateShoppingList(event.shoppingList.id, event.shoppingList);
        final updatedList = await dataRepo.fetchShoppingList(
          currentState.shoppingList.id.toString(),
        );

        emit(
          LoadedShoppingListDetailState(shoppingList: updatedList),
        );
      }
    });


    on<DeleteShoppingListItemEvent>((event, emit) {
      final currentState = state as LoadedShoppingListDetailState;
      final updatedItems = currentState.shoppingList.shoppingItems
          .where((i) => i.id != event.item.id)
          .toList();
      dataRepo.removeShoppingItem(event.shoppingListId, event.item.id);
      emit(LoadedShoppingListDetailState(
        shoppingList: currentState.shoppingList.copyWith(
          shoppingItems: updatedItems,
        ),
      ));
    });
  }
}
