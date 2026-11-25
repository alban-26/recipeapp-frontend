import 'dart:async';

import 'package:dio/dio.dart';

import '../StorageRepository.dart';
import '../api/BaseApiClient.dart';
import '../offline/ConnectionStatus.dart';
import '../offline/LocalStore.dart';
import '../offline/SyncQueue.dart';
import 'ReorderShoppingItemsRequest.dart';
import 'ShoppingListMutations.dart';
import 'domain/ShoppingItem.dart';
import 'domain/ShoppingList.dart';
import 'domain/Unit.dart';

class ShoppingListApiClient extends BaseApiClient {
  final StorageRepository storageRepository;

  ShoppingListApiClient({
    required super.dio,
    required super.secureStorage,
    required super.baseUrl,
    required this.storageRepository,
  });

  Future<List<ShoppingList>> getShoppingLists() async {
    final response = await dio.get('$baseUrl/shoppingLists');
    if (response.statusCode == 204 ||
        response.data == null ||
        response.data == "") {
      return [];
    }
    final shoppingLists =
        (response.data as List).map((e) => ShoppingList.fromJson(e)).toList();

    return shoppingLists;
  }

  Future<ShoppingList> getShoppingList(String id) async {
    final response = await dio.get('$baseUrl/shoppingLists/$id');
    return ShoppingList.fromJson(response.data);
  }

  Future<int?> deleteShoppingList(String id) async {
    final response = await dio.delete('$baseUrl/shoppingLists/$id');
    return response.statusCode;
  }

  Future<int> createShoppingList(ShoppingList shoppingList) async {
    final response = await dio.post(
      '$baseUrl/shoppingLists',
      data: shoppingList.toJson(),
    );

    if (response.data != null) {
      return response.data as int;
    } else {
      throw Exception("Invalid response: ${response.data}");
    }
  }

  Future<void> updateShoppingList(String id, ShoppingList shoppingList) async {
    await dio.put(
      '$baseUrl/shoppingLists/$id',
      data: shoppingList.toJson(),
    );
  }

  Future<List<ShoppingItem>> getShoppingItems(String listId) async {
    final response =
        await dio.get('$baseUrl/shoppingLists/$listId/shoppingItems');
    return (response.data as List)
        .map((e) => ShoppingItem.fromJson(e))
        .toList();
  }

  Future<ShoppingItem> getShoppingItemById(String listId, String itemId) async {
    final response =
        await dio.get('$baseUrl/shoppingLists/$listId/shoppingItems/$itemId');
    return ShoppingItem.fromJson(response.data);
  }

  Future<int> addShoppingItem(String listId, ShoppingItem item) async {
    final response = await dio.post(
      '$baseUrl/shoppingLists/$listId/shoppingItems',
      data: item.toJson(),
    );

    if (response.data != null) {
      return response.data as int;
    } else {
      throw Exception("Invalid response: ${response.data}");
    }
  }

  Future<void> updateShoppingItem(
      String listId, String itemId, ShoppingItem item) async {
    await dio.patch(
      '$baseUrl/shoppingLists/$listId/shoppingItems/$itemId',
      data: item.toJson(),
    );
  }

  Future<void> removeShoppingItem(String listId, String itemId) async {
    await dio.delete('$baseUrl/shoppingLists/$listId/shoppingItems/$itemId');
  }

  Future<void> reorderShoppingItem(
      String listId,
      ReorderShoppingItemsRequest reorderShoppingItemsRequest,
      ) async {
    await dio.post(
      '$baseUrl/shoppingLists/$listId/shoppingItems/reorder',
      data: reorderShoppingItemsRequest.toJson(),
    );
  }

  Future<void> reorderByCommon(String listId) async {
    await dio.post(
      '$baseUrl/shoppingLists/$listId/shoppingItems/reorderByCommon',
    );
  }

}

/// Einkaufslisten - funktionieren komplett ohne Verbindung.
///
/// Die lokale Kopie ist die Wahrheit fuer die Oberflaeche:
///  * Jede Aenderung wird SOFORT lokal eingetragen und gespeichert und landet
///    zusaetzlich in der [SyncQueue]. Auf das Netz wird dabei nie gewartet.
///  * Lesen: erst werden wartende Aenderungen zum Server geschickt, dann der
///    Serverstand geholt. Klappt das nicht, gibt es den lokalen Stand.
///  * Offline angelegte Listen und Eintraege tragen negative vorlaeufige IDs.
///    Alle Methoden hier akzeptieren weiterhin die vorlaeufige ID, auch nachdem
///    der Server laengst eine echte vergeben hat.
class ShoppingListRepository {
  static const _cacheKey = 'shopping_lists';
  static const _kindList = 'shoppingList';
  static const _kindItem = 'shoppingItem';

  static const _opCreateList = 'shopping.createList';
  static const _opUpdateList = 'shopping.updateList';
  static const _opDeleteList = 'shopping.deleteList';
  static const _opAddItem = 'shopping.addItem';
  static const _opUpdateItem = 'shopping.updateItem';
  static const _opRemoveItem = 'shopping.removeItem';
  static const _opReorder = 'shopping.reorder';
  static const _opReorderByCommon = 'shopping.reorderByCommon';

  final ShoppingListApiClient apiClient;
  final LocalStore store;
  final SyncQueue queue;

  /// null = es gibt noch gar keinen lokalen Stand.
  List<ShoppingList>? _lists;
  bool _loaded = false;
  Future<void>? _loading;
  Future<void>? _refreshing;

  /// Zaehlt lokale Aenderungen. Aendert sich der Wert, waehrend eine
  /// Server-Antwort unterwegs ist, ist diese Antwort veraltet und wird
  /// nicht uebernommen.
  int _generation = 0;

  final _changes = StreamController<void>.broadcast();
  StreamSubscription<void>? _reconnectedSub;

  ShoppingListRepository({
    required this.apiClient,
    required this.store,
    required this.queue,
    ConnectionStatus? connectionStatus,
  }) {
    queue.register(_opCreateList, _syncCreateList);
    queue.register(_opUpdateList, _syncUpdateList);
    queue.register(_opDeleteList, _syncDeleteList);
    queue.register(_opAddItem, _syncAddItem);
    queue.register(_opUpdateItem, _syncUpdateItem);
    queue.register(_opRemoveItem, _syncRemoveItem);
    queue.register(_opReorder, _syncReorder);
    queue.register(_opReorderByCommon, _syncReorderByCommon);

    // Die Verbindung ist zurueck: wartende Aenderungen abliefern, Serverstand
    // holen (dort kann sich inzwischen etwas getan haben) und offene
    // Bildschirme benachrichtigen.
    _reconnectedSub =
        connectionStatus?.onReconnected.listen((_) => _refreshInBackground());
  }

  /// Feuert, wenn sich der lokale Stand geaendert hat, OHNE dass der Aufrufer
  /// selbst etwas getan hat (Synchronisierung im Hintergrund). Wer zuhoert,
  /// liest danach mit `cacheOnly: true` neu.
  Stream<void> get changes => _changes.stream;

  // --- Laden / Speichern ----------------------------------------------------

  Future<void> _ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    final generation = _generation;
    await queue.load();
    List<ShoppingList>? loaded;
    try {
      final raw = await store.readJson(_cacheKey);
      if (raw is List) {
        loaded = raw
            .map((e) =>
                ShoppingList.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      print('[ShoppingListRepository] Lokale Listen nicht lesbar: $e');
    }
    // Wurde waehrenddessen zurueckgesetzt (Logout), nichts Altes uebernehmen.
    if (generation == _generation) {
      _lists = loaded;
      _loaded = true;
    }
    _loading = null;
  }

  void _persist() {
    final lists = _lists;
    if (lists == null) {
      store.remove(_cacheKey);
    } else {
      store.writeJson(_cacheKey, lists.map((l) => l.toJson()).toList());
    }
  }

  /// Nach einer lokalen Aenderung.
  void _touch() {
    _generation++;
    _persist();
  }

  List<ShoppingList> _snapshot() => List<ShoppingList>.of(_lists ?? const []);

  int _indexOf(int listId) {
    final lists = _lists;
    if (lists == null) return -1;
    final resolved = queue.resolve(_kindList, listId);
    return lists.indexWhere((l) => l.id == listId || l.id == resolved);
  }

  /// Wendet [change] auf die Liste an, falls sie lokal vorhanden ist.
  void _mutate(int listId, ShoppingList Function(ShoppingList list) change) {
    final index = _indexOf(listId);
    if (index >= 0) {
      final lists = List<ShoppingList>.of(_lists!);
      lists[index] = change(lists[index]);
      _lists = lists;
    }
    _touch();
  }

  /// Verwirft den lokalen Stand im Speicher (Logout / Nutzerwechsel). Die
  /// Dateien loescht der Aufrufer ueber den LocalStore.
  void resetCache() {
    _generation++;
    _lists = null;
    _loaded = false;
    _loading = null;
  }

  void dispose() {
    _reconnectedSub?.cancel();
    _changes.close();
  }

  // --- Lesen ----------------------------------------------------------------

  /// Der lokale Stand ohne Netzwerk - oder null, wenn es noch keinen gibt.
  Future<List<ShoppingList>?> cachedShoppingLists() async {
    await _ensureLoaded();
    return _lists == null ? null : _snapshot();
  }

  /// Aktueller Stand. Online vom Server, sonst der lokale.
  ///
  /// Wirft nur, wenn es weder Verbindung noch lokale Daten gibt.
  Future<List<ShoppingList>> fetchShoppingLists({bool cacheOnly = false}) async {
    await _ensureLoaded();
    if (!cacheOnly) {
      try {
        await _refreshAll();
      } catch (e) {
        if (_lists == null) rethrow;
        // Offline: der lokale Stand unten ist das Beste, was es gibt.
      }
    }
    return _snapshot();
  }

  Future<ShoppingList> fetchShoppingList(
    String shoppingListId, {
    bool cacheOnly = false,
  }) async {
    await _ensureLoaded();
    final id = int.parse(shoppingListId);
    if (!cacheOnly) {
      try {
        await _refreshOne(id);
      } catch (e) {
        if (_indexOf(id) < 0) rethrow;
      }
    }
    final index = _indexOf(id);
    if (index < 0) throw const OfflineException();
    return _lists![index];
  }

  Future<List<ShoppingItem>> fetchShoppingItems(int shoppingListId) async =>
      (await fetchShoppingList(shoppingListId.toString())).shoppingItems;

  Future<ShoppingItem> fetchShoppingItemById(
      int shoppingListId, int itemId) async {
    final resolved = queue.resolve(_kindItem, itemId);
    final items = await fetchShoppingItems(shoppingListId);
    return items.firstWhere((i) => i.id == itemId || i.id == resolved);
  }

  /// Holt alle Listen vom Server - aber erst, nachdem die eigenen wartenden
  /// Aenderungen dort angekommen sind. Sonst wuerde der (aeltere) Serverstand
  /// die lokalen Aenderungen ueberschreiben.
  Future<void> _refreshAll() {
    return _refreshing ??= _doRefreshAll().whenComplete(() {
      _refreshing = null;
    });
  }

  Future<void> _doRefreshAll() async {
    final synced = await queue.flush();
    if (!synced) {
      if (_lists == null) throw const OfflineException();
      return;
    }
    final generation = _generation;
    final remote = await apiClient.getShoppingLists();
    if (generation != _generation || queue.pendingCount > 0) return;
    _lists = remote;
    _persist();
  }

  Future<void> _refreshOne(int listId) async {
    final synced = await queue.flush();
    if (!synced) return;
    final realId = queue.resolve(_kindList, listId);
    if (SyncQueue.isTempId(realId)) return; // dem Server noch unbekannt
    final generation = _generation;
    final remote = await apiClient.getShoppingList(realId.toString());
    if (generation != _generation || queue.pendingCount > 0) return;
    final lists = List<ShoppingList>.of(_lists ?? const []);
    final index = lists.indexWhere((l) => l.id == remote.id);
    if (index >= 0) {
      lists[index] = remote;
    } else {
      lists.add(remote);
    }
    _lists = lists;
    _persist();
  }

  void _refreshInBackground() {
    // Nur wenn in dieser Sitzung schon mit Listen gearbeitet wurde - sonst ist
    // niemand angemeldet oder es schaut niemand hin.
    if (!_loaded || _lists == null) return;
    _refreshAll().then((_) {
      if (!_changes.isClosed) _changes.add(null);
    }).catchError((Object e) {
      // Offline o.ae. - beim naechsten Anlass wieder.
    });
  }

  // --- Schreiben (lokal + Warteschlange) ------------------------------------

  /// Legt die Liste an und liefert ihre (vorlaeufige) ID.
  Future<int> addShoppingList(ShoppingList shoppingList) async {
    if (!_loaded) await _ensureLoaded();

    final tempId = queue.newTempId();
    final items = shoppingList.shoppingItems;
    final list = shoppingList.copyWith(id: tempId, shoppingItems: const []);
    _lists = [...?_lists, list];
    _touch();
    queue.enqueue(_opCreateList, {'tempId': tempId, 'list': list.toJson()});

    for (final item in items) {
      await addShoppingItem(tempId, item);
    }
    return tempId;
  }

  Future<int?> removeShoppingList(int shoppingListId) async {
    if (!_loaded) await _ensureLoaded();

    final index = _indexOf(shoppingListId);
    if (index >= 0) {
      _lists = List<ShoppingList>.of(_lists!)..removeAt(index);
    }
    _touch();
    queue.enqueue(_opDeleteList, {'listId': shoppingListId});
    return 204;
  }

  /// Uebernimmt Titel und Sortierstrategie von [shoppingList]. Die Eintraege
  /// haben eigene Methoden und werden hier nicht angefasst.
  Future<void> updateShoppingList(
      int shoppingListId, ShoppingList shoppingList) async {
    if (!_loaded) await _ensureLoaded();

    _mutate(
      shoppingListId,
      (list) => withMeta(
        list,
        title: shoppingList.title,
        orderStrategy: shoppingList.orderStrategy,
      ),
    );
    queue.enqueue(_opUpdateList, {
      'listId': shoppingListId,
      // Ohne Eintraege: der Server aktualisiert dann nur Titel und Strategie
      // und ueberschreibt keine Eintraege mit einem evtl. aelteren Stand.
      'list': shoppingList
          .copyWith(id: shoppingListId, shoppingItems: const []).toJson(),
    });
  }

  /// Fuegt den Eintrag hinzu und liefert seine (vorlaeufige) ID.
  Future<int> addShoppingItem(int shoppingListId, ShoppingItem item) async {
    if (!_loaded) await _ensureLoaded();

    final tempId = queue.newTempId();
    final local = _normalizeUnit(item.copyWith(id: tempId));
    _mutate(shoppingListId, (list) => withItemAdded(list, local));
    queue.enqueue(_opAddItem, {
      'listId': shoppingListId,
      'tempId': tempId,
      'item': local.toJson(),
    });
    return tempId;
  }

  Future<void> updateShoppingItem(
      int shoppingListId, int itemId, ShoppingItem item) async {
    if (!_loaded) await _ensureLoaded();

    final local = _normalizeUnit(item.copyWith(id: itemId));
    _mutate(shoppingListId, (list) {
      // Die lokale Kopie kann inzwischen die echte ID tragen.
      final resolved = queue.resolve(_kindItem, itemId);
      final known = list.shoppingItems.any((i) => i.id == itemId)
          ? itemId
          : resolved;
      return withItemUpdated(list, local.copyWith(id: known));
    });
    queue.enqueue(_opUpdateItem, {
      'listId': shoppingListId,
      'itemId': itemId,
      'item': local.toJson(),
    });
  }

  Future<void> removeShoppingItem(int shoppingListId, int itemId) async {
    if (!_loaded) await _ensureLoaded();

    final resolved = queue.resolve(_kindItem, itemId);
    _mutate(
      shoppingListId,
      (list) => withItemRemoved(withItemRemoved(list, itemId), resolved),
    );
    queue.enqueue(_opRemoveItem, {'listId': shoppingListId, 'itemId': itemId});
  }

  /// [reorderShoppingItemsRequest] bezieht sich auf die nach Rang sortierte
  /// Liste (siehe [withItemMoved]).
  Future<void> reorderShoppingItem(int shoppingListId,
      ReorderShoppingItemsRequest reorderShoppingItemsRequest) async {
    if (!_loaded) await _ensureLoaded();

    _mutate(
      shoppingListId,
      (list) => withItemMoved(
        list,
        reorderShoppingItemsRequest.fromIndex,
        reorderShoppingItemsRequest.toIndex,
      ),
    );
    queue.enqueue(_opReorder, {
      'listId': shoppingListId,
      'fromIndex': reorderShoppingItemsRequest.fromIndex,
      'toIndex': reorderShoppingItemsRequest.toIndex,
    });
  }

  Future<void> reorderByCommon(int shoppingListId) async {
    if (!_loaded) await _ensureLoaded();

    _mutate(shoppingListId, withCommonOrder);
    queue.enqueue(_opReorderByCommon, {'listId': shoppingListId});
  }

  /// Der Server erwartet das Kurzzeichen ("Stück", "fl oz"). Frueher wurde der
  /// Name aus dem Code geschickt ("piece"), was bei "fluidOunce" scheiterte.
  ShoppingItem _normalizeUnit(ShoppingItem item) {
    final unit = Unit.tryParse(item.unit);
    return unit == null ? item : item.copyWith(unit: unit.label);
  }

  // --- Uebertragung zum Server (von der SyncQueue aufgerufen) ---------------

  /// Echte Listen-ID oder Abbruch: ist die Liste dem Server unbekannt (ihr
  /// Anlegen wurde abgelehnt), kann auch diese Aenderung nie ankommen.
  String _serverListId(PendingOp op) {
    final id = queue.resolve(_kindList, (op.data['listId'] as num).toInt());
    if (SyncQueue.isTempId(id)) {
      throw StateError('Liste ${op.data['listId']} existiert auf dem Server nicht');
    }
    return id.toString();
  }

  int _serverItemId(PendingOp op) {
    final id = queue.resolve(_kindItem, (op.data['itemId'] as num).toInt());
    if (SyncQueue.isTempId(id)) {
      throw StateError('Eintrag ${op.data['itemId']} existiert auf dem Server nicht');
    }
    return id;
  }

  Future<void> _syncCreateList(PendingOp op) async {
    final tempId = (op.data['tempId'] as num).toInt();
    final list =
        ShoppingList.fromJson(Map<String, dynamic>.from(op.data['list'] as Map));
    final realId = await apiClient.createShoppingList(list.copyWith(id: 0));
    queue.mapId(_kindList, tempId, realId);

    final lists = _lists;
    if (lists != null) {
      _lists = [
        for (final l in lists) l.id == tempId ? l.copyWith(id: realId) : l,
      ];
      _persist();
    }
  }

  Future<void> _syncUpdateList(PendingOp op) async {
    final id = _serverListId(op);
    final list =
        ShoppingList.fromJson(Map<String, dynamic>.from(op.data['list'] as Map));
    await apiClient.updateShoppingList(
      id,
      list.copyWith(id: int.parse(id), shoppingItems: const []),
    );
  }

  Future<void> _syncDeleteList(PendingOp op) async {
    try {
      await apiClient.deleteShoppingList(_serverListId(op));
    } on DioException catch (e) {
      // Schon weg (auf einem anderen Geraet geloescht, oder die Antwort auf
      // einen frueheren Versuch ging verloren): Ziel erreicht.
      if (e.response?.statusCode != 404) rethrow;
    }
  }

  Future<void> _syncAddItem(PendingOp op) async {
    final listId = _serverListId(op);
    final tempId = (op.data['tempId'] as num).toInt();
    final item =
        ShoppingItem.fromJson(Map<String, dynamic>.from(op.data['item'] as Map));
    final realId = await apiClient.addShoppingItem(listId, item.copyWith(id: 0));
    queue.mapId(_kindItem, tempId, realId);

    final lists = _lists;
    if (lists != null) {
      _lists = [
        for (final l in lists)
          l.copyWith(shoppingItems: [
            for (final i in l.shoppingItems)
              i.id == tempId ? i.copyWith(id: realId) : i,
          ]),
      ];
      _persist();
    }
  }

  Future<void> _syncUpdateItem(PendingOp op) async {
    final listId = _serverListId(op);
    final itemId = _serverItemId(op);
    final item =
        ShoppingItem.fromJson(Map<String, dynamic>.from(op.data['item'] as Map));
    await apiClient.updateShoppingItem(
      listId,
      itemId.toString(),
      item.copyWith(id: itemId),
    );
  }

  Future<void> _syncRemoveItem(PendingOp op) async {
    await apiClient.removeShoppingItem(
      _serverListId(op),
      _serverItemId(op).toString(),
    );
  }

  Future<void> _syncReorder(PendingOp op) async {
    await apiClient.reorderShoppingItem(
      _serverListId(op),
      ReorderShoppingItemsRequest(
        fromIndex: (op.data['fromIndex'] as num).toInt(),
        toIndex: (op.data['toIndex'] as num).toInt(),
      ),
    );
  }

  Future<void> _syncReorderByCommon(PendingOp op) async {
    await apiClient.reorderByCommon(_serverListId(op));
  }
}
