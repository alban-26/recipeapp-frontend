import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../ShoppingListRepository.dart';
import '../domain/ShoppingList.dart';
import '../navigation/ShoppingListNavigatorCubit.dart';
import 'ShoppingListEvent.dart';
import 'ShoppingListState.dart';

class ShoppingListBloc extends Bloc<ShoppingListEvent, ShoppingListState> {
  final ShoppingListRepository dataRepo;
  final ShoppingNavigatorCubit recipeNavigatorCubit;

  StreamSubscription<void>? _changesSub;

  ShoppingListBloc({required this.dataRepo, required this.recipeNavigatorCubit}) : super(LoadingShoppingListState()) {
    on<LoadShoppingListEvent>((event, emit) async {
      // Gespeicherten Stand sofort zeigen, erst danach den Server fragen.
      // So ist die Seite auch ohne (oder mit sehr langsamer) Verbindung
      // sofort da.
      List<ShoppingList>? cached;
      try {
        cached = await dataRepo.cachedShoppingLists();
      } catch (_) {}

      if (cached != null) {
        emit(LoadedShoppingListState(shoppingLists: cached));
      } else {
        emit(LoadingShoppingListState());
      }

      try {
        final shoppingLists = await dataRepo.fetchShoppingLists();
        emit(LoadedShoppingListState(shoppingLists: shoppingLists));
      } catch (exception) {
        if (cached == null) {
          emit(FailedToLoadShoppingListState(error: exception));
        }
      }
    });
    on<PullToRefreshEvent>((event, emit) async {
      try {
        final shoppingLists = await dataRepo.fetchShoppingLists();
        emit(LoadedShoppingListState(shoppingLists: shoppingLists));
      } catch (exception) {
        emit(FailedToLoadShoppingListState(error: exception));
      }
    });
    on<ShoppingListAdded>((event, emit) async {
      try {
        // Kehrt sofort zurueck - angelegt wird lokal, der Server folgt.
        int insertedId = await dataRepo.addShoppingList(event.shoppingList);
        await _emitLocal(emit);
        recipeNavigatorCubit.showShoppingListDetail(event.shoppingList.copyWith(id: insertedId));

      } catch (exception) {
        emit(FailedToLoadShoppingListState(error: exception));
      }
    });
    on<ShoppingListDeleted>((event, emit) async {
      try {
        await dataRepo.removeShoppingList(event.shoppingList.id);
        await _emitLocal(emit);
      } catch (exception) {
        emit(FailedToLoadShoppingListState(error: exception));
      }
    });
    on<ShoppingListRenamed>((event, emit) async {
      try {
        await dataRepo.updateShoppingList(
          event.shoppingList.id,
          event.shoppingList.copyWith(title: event.title),
        );
        await _emitLocal(emit);
      } catch (exception) {
        emit(FailedToLoadShoppingListState(error: exception));
      }
    });
    on<ShoppingListsSyncedEvent>((event, emit) async {
      if (state is! LoadedShoppingListState) return;
      try {
        await _emitLocal(emit);
      } catch (_) {}
    });

    _changesSub = dataRepo.changes.listen((_) {
      if (!isClosed) add(ShoppingListsSyncedEvent());
    });
  }

  /// Zeigt den lokalen Stand an (ohne Netzwerk).
  Future<void> _emitLocal(Emitter<ShoppingListState> emit) async {
    final shoppingLists = await dataRepo.fetchShoppingLists(cacheOnly: true);
    emit(LoadedShoppingListState(shoppingLists: shoppingLists));
  }

  @override
  Future<void> close() {
    _changesSub?.cancel();
    return super.close();
  }
}
