import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipeapp_frontend/StorageRepository.dart';
import 'package:recipeapp_frontend/offline/ConnectionStatus.dart';
import 'package:recipeapp_frontend/offline/LocalStore.dart';
import 'package:recipeapp_frontend/offline/OfflineData.dart';
import 'package:recipeapp_frontend/offline/SyncQueue.dart';
import 'package:recipeapp_frontend/shopping/ReorderShoppingItemsRequest.dart';
import 'package:recipeapp_frontend/shopping/ShoppingListRepository.dart';
import 'package:recipeapp_frontend/shopping/domain/Product.dart';
import 'package:recipeapp_frontend/shopping/domain/ProductOrderStrategy.dart';
import 'package:recipeapp_frontend/shopping/domain/ShoppingItem.dart';
import 'package:recipeapp_frontend/shopping/domain/ShoppingList.dart';

import 'support/fake_backend.dart';

const _base = 'http://test.local';

/// Die App, wie main.dart sie verdrahtet - nur mit nachgestelltem Server und
/// Ablage im Speicher. [restart] simuliert einen Neustart der App: alles neu,
/// nur die gespeicherten Daten bleiben.
class Harness {
  final FakeBackend backend;
  final LocalStore store;
  late ConnectionStatus status;
  late SyncQueue queue;
  late ShoppingListRepository repo;
  final failures = <SyncFailure>[];

  Harness({FakeBackend? backend, LocalStore? store})
      : backend = backend ?? FakeBackend(),
        store = store ?? MemoryLocalStore() {
    _wire();
  }

  void _wire() {
    status = ConnectionStatus();
    final dio = Dio()
      ..httpClientAdapter = backend
      ..interceptors.add(ConnectivityInterceptor(status));
    const secure = FlutterSecureStorage();
    queue = SyncQueue(store: store);
    queue.failures.listen(failures.add);
    repo = ShoppingListRepository(
      apiClient: ShoppingListApiClient(
        dio: dio,
        secureStorage: secure,
        baseUrl: _base,
        storageRepository:
            StorageRepository(dio: dio, secureStorage: secure, baseUrl: _base),
      ),
      store: store,
      queue: queue,
      connectionStatus: status,
    );
  }

  void restart() => _wire();

  /// Wartet, bis die Warteschlange nichts mehr zu tun hat.
  Future<bool> sync() => queue.flush();
}

ShoppingItem newItem(
  String name, {
  double quantity = 1,
  String unit = 'Stück',
  int rank = 0,
  ProductCategory category = ProductCategory.OTHER,
}) =>
    ShoppingItem(
      id: 0,
      product: Product(name: name, category: category),
      quantity: quantity,
      unit: unit,
      checked: false,
      rank: rank,
    );

ShoppingList newList(String title) => ShoppingList(
      id: 0,
      title: title,
      shoppingItems: const [],
      createdAt: DateTime(2026, 11, 22, 18, 30),
    );

List<String> names(ShoppingList list) =>
    list.shoppingItems.map((i) => i.product.name).toList();

void main() {
  group('online', () {
    test('Liste anlegen, Eintrag hinzufügen - landet beim Server', () async {
      final h = Harness();

      final listId = await h.repo.addShoppingList(newList('Wocheneinkauf'));
      await h.repo.addShoppingItem(listId, newItem('Äpfel', quantity: 3));
      expect(await h.sync(), isTrue);

      expect(h.backend.lists, hasLength(1));
      final serverId = h.backend.lists.keys.single;
      expect(h.backend.lists[serverId]!['title'], 'Wocheneinkauf');
      expect(h.backend.itemNames(serverId), ['Äpfel']);
      expect(h.queue.pendingCount, 0);

      // Die vorläufige ID funktioniert weiter, liefert aber die echte Liste.
      final list = await h.repo.fetchShoppingList(listId.toString());
      expect(list.id, serverId);
      expect(list.shoppingItems.single.id,
          h.backend.itemByName(serverId, 'Äpfel')['id']);
    });

    test('Umbenennen kommt an und überschreibt keine Einträge', () async {
      final h = Harness();
      final id = h.backend.seedList('Alt', items: [
        {'name': 'Milch', 'quantity': 2.0, 'unit': 'LITER', 'checked': true},
      ]);
      final list = (await h.repo.fetchShoppingLists()).single;

      await h.repo.updateShoppingList(id, list.copyWith(title: 'Neu'));
      await h.sync();

      expect(h.backend.lists[id]!['title'], 'Neu');
      final milk = h.backend.itemByName(id, 'Milch');
      expect(milk['quantity'], 2.0);
      expect(milk['checked'], isTrue);
      expect((await h.repo.fetchShoppingLists()).single.title, 'Neu');
    });

    test('Eintrag bearbeiten: Name, Menge und Einheit kommen an', () async {
      final h = Harness();
      final id = h.backend.seedList('Liste', items: [
        {'name': 'Apfel', 'quantity': 1.0, 'unit': 'PIECE'},
      ]);
      final item = (await h.repo.fetchShoppingLists()).single.shoppingItems.single;

      await h.repo.updateShoppingItem(
        id,
        item.id,
        item.copyWith(
          product:
              const Product(name: 'Äpfel', category: ProductCategory.FRUITS),
          quantity: 1.5,
          unit: 'kg',
        ),
      );
      await h.sync();

      final server = h.backend.lists[id]!['items'] as List;
      expect(server.single['name'], 'Äpfel');
      expect(server.single['category'], 'FRUITS');
      expect(server.single['quantity'], 1.5);
      expect(server.single['unit'], 'KILOGRAM');
    });

    test('Einheit geht als Kurzzeichen raus (früher scheiterte "fl oz")',
        () async {
      final h = Harness();
      final id = h.backend.seedList('Bar');
      await h.repo.fetchShoppingLists();

      // So hat der alte Dialog die Einheit geschickt: als Namen aus dem Code.
      await h.repo.addShoppingItem(id, newItem('Rum', unit: 'fluidOunce'));
      await h.sync();

      expect(h.failures, isEmpty);
      expect(h.backend.itemByName(id, 'Rum')['unit'], 'FLUID_OUNCE');
    });
  });

  group('offline', () {
    test('alles geht ohne Verbindung und wird später nachgereicht', () async {
      final h = Harness();
      final existing = h.backend.seedList('Wocheneinkauf', items: [
        {'name': 'Milch'},
        {'name': 'Brot'},
      ]);
      // Einmal online gewesen: die Liste liegt lokal vor.
      final loaded = (await h.repo.fetchShoppingLists()).single;
      final milk = loaded.shoppingItems.first;
      final bread = loaded.shoppingItems.last;

      h.backend.offline = true;
      h.backend.log.clear();

      // Im Laden, kein Netz: abhaken, hinzufügen, bearbeiten, löschen, umbenennen.
      await h.repo.updateShoppingItem(
          existing, milk.id, milk.copyWith(checked: true));
      final butterId = await h.repo
          .addShoppingItem(existing, newItem('Butter', rank: 2));
      await h.repo.updateShoppingItem(
        existing,
        butterId,
        newItem('Butter', quantity: 250, unit: 'g', rank: 2)
            .copyWith(id: butterId),
      );
      await h.repo.removeShoppingItem(existing, bread.id);
      await h.repo.updateShoppingList(
          existing, loaded.copyWith(title: 'Samstag'));
      // ... und gleich noch eine neue Liste samt Eintrag.
      final partyId = await h.repo.addShoppingList(newList('Party'));
      await h.repo.addShoppingItem(partyId, newItem('Chips', quantity: 3));

      expect(await h.sync(), isFalse);
      expect(h.status.isOffline, isTrue);
      expect(h.backend.log, isEmpty, reason: 'nichts hat den Server erreicht');
      expect(h.queue.pendingCount, 7);

      // Die App zeigt trotzdem sofort den neuen Stand.
      final offlineLists = await h.repo.fetchShoppingLists();
      expect(offlineLists.map((l) => l.title), ['Samstag', 'Party']);
      expect(names(offlineLists[0]), ['Milch', 'Butter']);
      expect(offlineLists[0].shoppingItems.first.checked, isTrue);
      expect(offlineLists[0].shoppingItems.last.quantity, 250);
      expect(offlineLists[0].shoppingItems.last.unit, 'g');
      expect(names(offlineLists[1]), ['Chips']);

      // Wieder Netz.
      h.backend.offline = false;
      expect(await h.sync(), isTrue);
      expect(h.failures, isEmpty);
      expect(h.queue.pendingCount, 0);

      expect(h.backend.lists[existing]!['title'], 'Samstag');
      expect(h.backend.itemNames(existing), ['Milch', 'Butter']);
      expect(h.backend.itemByName(existing, 'Milch')['checked'], isTrue);
      expect(h.backend.itemByName(existing, 'Butter')['quantity'], 250);
      expect(h.backend.itemByName(existing, 'Butter')['unit'], 'GRAM');

      final partyServerId =
          h.backend.lists.keys.firstWhere((id) => id != existing);
      expect(h.backend.lists[partyServerId]!['title'], 'Party');
      expect(h.backend.itemNames(partyServerId), ['Chips']);

      // Nach dem Abgleich stimmen lokaler Stand und Server überein.
      final synced = await h.repo.fetchShoppingLists();
      expect(synced.map((l) => l.id), [existing, partyServerId]);
      expect(names(synced[0]), h.backend.itemNames(existing));
      expect(h.status.isOffline, isFalse);
    });

    test('wartende Änderungen überleben einen Neustart der App', () async {
      final h = Harness();
      final id = h.backend.seedList('Liste', items: [
        {'name': 'Milch'},
      ]);
      final milk = (await h.repo.fetchShoppingLists()).single.shoppingItems.single;

      h.backend.offline = true;
      await h.repo.updateShoppingItem(id, milk.id, milk.copyWith(checked: true));
      final newListId = await h.repo.addShoppingList(newList('Neu'));
      await h.repo.addShoppingItem(newListId, newItem('Eier', quantity: 6));
      await h.sync();

      h.restart(); // App beendet und neu gestartet, immer noch offline

      final afterRestart = await h.repo.fetchShoppingLists();
      expect(afterRestart.map((l) => l.title), ['Liste', 'Neu']);
      expect(afterRestart[0].shoppingItems.single.checked, isTrue);
      expect(names(afterRestart[1]), ['Eier']);
      expect(h.queue.pendingCount, 3);

      h.backend.offline = false;
      expect(await h.sync(), isTrue);

      expect(h.backend.itemByName(id, 'Milch')['checked'], isTrue);
      final created = h.backend.lists.keys.firstWhere((k) => k != id);
      expect(h.backend.itemNames(created), ['Eier']);

      // Auch die vorläufige ID von vor dem Neustart findet die Liste noch.
      expect((await h.repo.fetchShoppingList(newListId.toString())).id, created);
    });

    test('Umsortieren offline ergibt dieselbe Reihenfolge wie auf dem Server',
        () async {
      final h = Harness();
      final id = h.backend.seedList('Liste', items: [
        {'name': 'A'},
        {'name': 'B'},
        {'name': 'C'},
        {'name': 'D'},
      ]);
      await h.repo.fetchShoppingLists();

      h.backend.offline = true;
      await h.repo.reorderShoppingItem(
          id, const ReorderShoppingItemsRequest(fromIndex: 3, toIndex: 0));
      await h.repo.reorderShoppingItem(
          id, const ReorderShoppingItemsRequest(fromIndex: 1, toIndex: 2));

      final local = (await h.repo.fetchShoppingLists()).single;
      expect(names(local), ['D', 'B', 'A', 'C']);

      h.backend.offline = false;
      await h.sync();
      expect(h.backend.itemNames(id), ['D', 'B', 'A', 'C']);
    });

    test('"Nach Beliebtheit sortieren" offline wie auf dem Server', () async {
      final h = Harness();
      final id = h.backend.seedList('Liste', items: [
        {'name': 'Schrauben', 'category': 'OTHER'},
        {'name': 'Milch', 'category': 'DAIRY'},
        {'name': 'Tomaten', 'category': 'VEGETABLES'},
      ]);
      final list = (await h.repo.fetchShoppingLists()).single;

      h.backend.offline = true;
      // Dieselben zwei Schritte wie im Menü der Detailseite.
      await h.repo.reorderByCommon(id);
      await h.repo.updateShoppingList(
        id,
        list.copyWith(orderStrategy: ProductOrderStrategy.COMMON_ORDER),
      );

      final local = (await h.repo.fetchShoppingLists()).single;
      expect(names(local), ['Tomaten', 'Milch', 'Schrauben']);
      expect(local.orderStrategy, ProductOrderStrategy.COMMON_ORDER);

      h.backend.offline = false;
      await h.sync();
      expect(h.backend.itemNames(id), ['Tomaten', 'Milch', 'Schrauben']);
      expect(h.backend.lists[id]!['orderStrategy'], 'COMMON_ORDER');
    });

    test('ohne Verbindung und ohne gespeicherte Daten gibt es einen klaren Fehler',
        () async {
      final h = Harness();
      h.backend.offline = true;

      expect(await h.repo.cachedShoppingLists(), isNull);
      await expectLater(
        h.repo.fetchShoppingLists(),
        throwsA(predicate(isConnectivityFailure)),
      );
    });

    test('ganz ohne Server-Kontakt lässt sich trotzdem eine Liste anlegen',
        () async {
      final h = Harness();
      h.backend.offline = true;

      final id = await h.repo.addShoppingList(newList('Erste Liste'));
      await h.repo.addShoppingItem(id, newItem('Kaffee'));

      final lists = await h.repo.fetchShoppingLists();
      expect(lists.single.title, 'Erste Liste');
      expect(names(lists.single), ['Kaffee']);
    });
  });

  group('Abgleich', () {
    test('eine verspätete Server-Antwort überschreibt keine neuere Änderung',
        () async {
      final h = Harness();
      final id = h.backend.seedList('Liste', items: [
        {'name': 'Milch'},
      ]);
      final milk = (await h.repo.fetchShoppingLists()).single.shoppingItems.single;

      // Die nächste Listen-Abfrage bleibt "in der Leitung" hängen ...
      final release = Completer<void>();
      h.backend.beforeRespond = (request) async {
        if (request == 'GET /shoppingLists') await release.future;
      };
      final refresh = h.repo.fetchShoppingLists();
      await pumpEventQueue();

      // ... währenddessen hakt der Nutzer ab.
      h.backend.beforeRespond = null;
      await h.repo.updateShoppingItem(id, milk.id, milk.copyWith(checked: true));

      release.complete();
      final result = await refresh;

      expect(result.single.shoppingItems.single.checked, isTrue,
          reason: 'der alte Serverstand darf den Haken nicht wieder entfernen');
      await h.sync();
      expect(h.backend.itemByName(id, 'Milch')['checked'], isTrue);
    });

    test('lehnt der Server eine Änderung endgültig ab, blockiert sie nicht den Rest',
        () async {
      final h = Harness();
      final gone = h.backend.seedList('Wird gelöscht', items: [
        {'name': 'X'},
      ]);
      final kept = h.backend.seedList('Bleibt', items: [
        {'name': 'Milch'},
      ]);
      final lists = await h.repo.fetchShoppingLists();
      final milk = lists[1].shoppingItems.single;

      h.backend.offline = true;
      await h.repo.updateShoppingList(
          gone, lists[0].copyWith(title: 'Umbenannt'));
      await h.repo.updateShoppingItem(
          kept, milk.id, milk.copyWith(checked: true));

      // Inzwischen wurde die erste Liste auf einem anderen Gerät gelöscht.
      h.backend.lists.remove(gone);
      h.backend.offline = false;

      expect(await h.sync(), isTrue);
      expect(h.failures, hasLength(1));
      expect(h.failures.single.op.type, 'shopping.updateList');
      expect(h.backend.itemByName(kept, 'Milch')['checked'], isTrue);

      // Der lokale Stand folgt danach wieder dem Server.
      expect((await h.repo.fetchShoppingLists()).map((l) => l.title), ['Bleibt']);
    });

    test('Liste offline gelöscht, die es auf dem Server schon nicht mehr gibt: kein Fehler',
        () async {
      final h = Harness();
      final id = h.backend.seedList('Doppelt gelöscht');
      await h.repo.fetchShoppingLists();

      h.backend.offline = true;
      await h.repo.removeShoppingList(id);
      h.backend.lists.remove(id); // anderes Gerät war schneller
      h.backend.offline = false;

      expect(await h.sync(), isTrue);
      expect(h.failures, isEmpty);
      expect(await h.repo.fetchShoppingLists(), isEmpty);
    });

    test('Serverfehler (500) wird ein paar Mal versucht, dann verworfen',
        () async {
      final h = Harness();
      final id = h.backend.seedList('Liste', items: [
        {'name': 'Milch'},
        {'name': 'Brot'},
      ]);
      final items = (await h.repo.fetchShoppingLists()).single.shoppingItems;

      // Der Server liefert für das Löschen eines unbekannten Eintrags 500.
      h.backend.forcedStatus[RegExp(r'^DELETE .*/shoppingItems/')] = 500;
      await h.repo.removeShoppingItem(id, items[0].id);
      await h.repo.updateShoppingItem(
          id, items[1].id, items[1].copyWith(checked: true));

      expect(await h.sync(), isFalse, reason: '1. Versuch: bleibt liegen');
      expect(h.queue.pendingCount, 2);
      expect(await h.sync(), isFalse, reason: '2. Versuch');
      expect(await h.sync(), isTrue, reason: '3. Versuch: verworfen, weiter');

      expect(h.failures.single.op.type, 'shopping.removeItem');
      expect(h.backend.itemByName(id, 'Brot')['checked'], isTrue);
    });

    test('401 (Sitzung wird erneuert) verwirft nichts', () async {
      final h = Harness();
      final id = h.backend.seedList('Liste', items: [
        {'name': 'Milch'},
      ]);
      final milk = (await h.repo.fetchShoppingLists()).single.shoppingItems.single;

      h.backend.forcedStatus[RegExp(r'^PATCH ')] = 401;
      await h.repo.updateShoppingItem(id, milk.id, milk.copyWith(checked: true));
      for (var i = 0; i < 6; i++) {
        expect(await h.sync(), isFalse);
      }
      expect(h.queue.pendingCount, 1);
      expect(h.failures, isEmpty);

      h.backend.forcedStatus.clear();
      expect(await h.sync(), isTrue);
      expect(h.backend.itemByName(id, 'Milch')['checked'], isTrue);
    });

    test('kommt die Verbindung zurück, wird der Serverstand geholt', () async {
      final h = Harness();
      final id = h.backend.seedList('Liste', items: [
        {'name': 'Milch'},
      ]);
      await h.repo.fetchShoppingLists();
      var notified = 0;
      h.repo.changes.listen((_) => notified++);

      h.backend.offline = true;
      await expectLater(h.repo.fetchShoppingLists(), completes);
      expect(h.status.isOffline, isTrue);

      // Auf einem anderen Gerät kommt etwas dazu; dann ist das Netz wieder da.
      h.backend.seedItem(id, 'Brot');
      h.backend.offline = false;
      final milk = (await h.repo.cachedShoppingLists())!.single.shoppingItems.single;
      await h.repo.updateShoppingItem(id, milk.id, milk.copyWith(checked: true));
      await h.sync();
      await pumpEventQueue();

      expect(notified, 1);
      final lists = (await h.repo.cachedShoppingLists())!;
      expect(names(lists.single), ['Milch', 'Brot']);
      expect(lists.single.shoppingItems.first.checked, isTrue);
    });
  });

  group('Konto', () {
    test('nach dem Abmelden ist nichts mehr da - auch keine wartende Änderung',
        () async {
      final h = Harness();
      final data = OfflineData(store: h.store, queue: h.queue)
        ..onReset(h.repo.resetCache);
      await data.ensureOwner('anna');
      h.backend.seedList('Annas Liste');
      await h.repo.fetchShoppingLists();
      h.backend.offline = true;
      await h.repo.addShoppingList(newList('Noch nicht übertragen'));
      await h.sync();
      expect(h.queue.pendingCount, 1);

      await data.wipe();

      expect(h.queue.pendingCount, 0);
      expect(await h.repo.cachedShoppingLists(), isNull);
      expect(data.isReady, isFalse);

      // Auch nach einem Neustart taucht nichts wieder auf.
      h.restart();
      expect(await h.repo.cachedShoppingLists(), isNull);
      expect(h.queue.pendingCount, 0);
    });

    test('meldet sich jemand anderes an, werden fremde Daten verworfen',
        () async {
      final h = Harness();
      final data = OfflineData(store: h.store, queue: h.queue)
        ..onReset(h.repo.resetCache);
      await data.ensureOwner('anna');
      h.backend.seedList('Annas Liste');
      await h.repo.fetchShoppingLists();

      await data.ensureOwner('anna'); // dieselbe Person: alles bleibt
      expect((await h.repo.cachedShoppingLists())!.single.title, 'Annas Liste');

      await data.ensureOwner('ben');
      expect(await h.repo.cachedShoppingLists(), isNull);
      expect(data.isReady, isTrue);
    });
  });
}
