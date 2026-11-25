import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/shopping/ShoppingListRepository.dart';
import '../../recipe/services/ingredients_service.dart';
import '../ReorderShoppingItemsRequest.dart';
import '../ShoppingListMutations.dart';
import '../domain/ShoppingList.dart';
import 'ShoppingListDetailEvent.dart';
import 'ShoppingListDetailState.dart';

/// Alle Aenderungen werden sofort angezeigt und lokal gespeichert; das
/// Repository liefert sie an den Server, sobald der erreichbar ist. Deshalb
/// wartet hier nichts auf das Netz und nichts scheitert ohne Verbindung.
class ShoppingListDetailBloc
    extends Bloc<ShoppingListDetailEvent, ShoppingListsDetailState> {

  final ShoppingListRepository dataRepo;

  StreamSubscription<void>? _changesSub;

  ShoppingListDetailBloc({required this.dataRepo, required ShoppingList initialList})
      : super(LoadedShoppingListDetailState(shoppingList: initialList)) {
    on<LoadShoppingListDetailEvent>((event, emit) {
      emit(state);
    });

    on<LoadIngredientsRequested>((event, emit) async {
      final ingredients = await IngredientsService.loadShoppingItems();
      emit(_current.copyWith(allIngredients: ingredients));

    });
    add(LoadIngredientsRequested());

    on<RefreshShoppingListDetailEvent>((event, emit) async {
      try {
        final updatedList = await dataRepo.fetchShoppingList(
          _current.shoppingList.id.toString(),
        );

        emit(_current.copyWith(shoppingList: updatedList));
      } catch (e) {
        // Offline und nichts Neues: Anzeige bleibt, wie sie ist.
      }
    });


    on<ReorderShoppingListItemsEvent>((event, emit) async {
      final list = _current.shoppingList;

      // Bildschirm-Positionen in Rang-Positionen uebersetzen: abgehakte
      // Eintraege stehen auf dem Bildschirm unten, im Rang aber evtl. mittendrin.
      final move = displayMoveToRankMove(
        list.shoppingItems,
        event.fromIndex,
        event.toIndex,
      );
      if (move == null) return;

      emit(_current.copyWith(
        shoppingList: withItemMoved(list, move[0], move[1]),
      ));

      await dataRepo.reorderShoppingItem(
        list.id,
        ReorderShoppingItemsRequest(fromIndex: move[0], toIndex: move[1]),
      );
    });

    on<ReorderByCommonEvent>((event, emit) async {
      final list = _current.shoppingList;

      await dataRepo.reorderByCommon(list.id);
      await _emitLocal(emit, fallback: withCommonOrder);
    });


    on<AddShoppingListItemEvent>((event, emit) async {
      final list = _current.shoppingList;
      int insertedId = await dataRepo.addShoppingItem(list.id, event.item);

      await _emitLocal(
        emit,
        fallback: (current) =>
            withItemAdded(current, event.item.copyWith(id: insertedId)),
      );
    });

    on<ToggleShoppingListItemEvent>((event, emit) async {
      final list = _current.shoppingList;

      emit(_current.copyWith(
        shoppingList: withItemUpdated(list, event.item),
      ));

      await dataRepo.updateShoppingItem(list.id, event.item.id, event.item);
    });

    on<EditShoppingListItemEvent>((event, emit) async {
      final list = _current.shoppingList;

      emit(_current.copyWith(
        shoppingList: withItemUpdated(list, event.item),
      ));

      await dataRepo.updateShoppingItem(list.id, event.item.id, event.item);
      // Bei Sortierung nach Kategorie kann der Eintrag jetzt woanders stehen.
      await _emitLocal(emit);
    });

    on<UpdateShoppingListEvent>((event, emit) async {
      await _updateMeta(emit, event.shoppingList);
    });

    on<RenameShoppingListEvent>((event, emit) async {
      final title = event.title.trim();
      if (title.isEmpty) return;
      await _updateMeta(emit, _current.shoppingList.copyWith(title: title));
    });


    on<DeleteShoppingListItemEvent>((event, emit) async {
      final list = _current.shoppingList;

      emit(_current.copyWith(
        shoppingList: withItemRemoved(list, event.item.id),
      ));

      await dataRepo.removeShoppingItem(list.id, event.item.id);
    });

    on<ShoppingListSyncedEvent>((event, emit) async {
      await _emitLocal(emit);
    });

    _changesSub = dataRepo.changes.listen((_) {
      if (!isClosed) add(ShoppingListSyncedEvent());
    });
  }

  /// Dieser Bloc kennt nur einen State-Typ.
  LoadedShoppingListDetailState get _current =>
      state as LoadedShoppingListDetailState;

  /// Titel bzw. Sortierstrategie uebernehmen.
  Future<void> _updateMeta(
    Emitter<ShoppingListsDetailState> emit,
    ShoppingList updated,
  ) async {
    await dataRepo.updateShoppingList(_current.shoppingList.id, updated);
    await _emitLocal(
      emit,
      fallback: (current) => withMeta(
        current,
        title: updated.title,
        orderStrategy: updated.orderStrategy,
      ),
    );
  }

  /// Uebernimmt den lokalen Stand des Repositories - dort liegt die Liste so,
  /// wie sie auch der Server ausliefern wuerde (IDs, Reihenfolge).
  ///
  /// Kennt das Repository die Liste nicht (mehr), greift [fallback].
  Future<void> _emitLocal(
    Emitter<ShoppingListsDetailState> emit, {
    ShoppingList Function(ShoppingList current)? fallback,
  }) async {
    ShoppingList? local;
    try {
      local = await dataRepo.fetchShoppingList(
        _current.shoppingList.id.toString(),
        cacheOnly: true,
      );
    } catch (_) {}

    if (isClosed) return;
    if (local != null) {
      emit(_current.copyWith(shoppingList: local));
    } else if (fallback != null) {
      emit(_current.copyWith(shoppingList: fallback(_current.shoppingList)));
    }
  }

  @override
  Future<void> close() {
    _changesSub?.cancel();
    return super.close();
  }
}
