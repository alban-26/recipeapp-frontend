import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipeapp_frontend/StorageRepository.dart';
import 'package:recipeapp_frontend/offline/ConnectionStatus.dart';
import 'package:recipeapp_frontend/offline/LocalStore.dart';
import 'package:recipeapp_frontend/offline/SyncQueue.dart';
import 'package:recipeapp_frontend/shopping/ShoppingListRepository.dart';
import 'package:recipeapp_frontend/shopping/detail_screen/ShoppingListDetailScreen.dart';
import 'package:recipeapp_frontend/shopping/list_screen/ShoppingListScreen.dart';
import 'package:recipeapp_frontend/shopping/navigation/ShoppingListNavigatorCubit.dart';

import 'support/fake_backend.dart';
import 'support/screen_testing.dart';

const _base = 'http://test.local';

class Harness {
  final backend = FakeBackend();
  final store = MemoryLocalStore();
  final status = ConnectionStatus();
  late final SyncQueue queue;
  late final ShoppingListRepository repo;

  Harness() {
    final dio = Dio()
      ..httpClientAdapter = backend
      ..interceptors.add(ConnectivityInterceptor(status));
    const secure = FlutterSecureStorage();
    queue = SyncQueue(store: store);
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

  Widget app(Widget home) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: repo),
          RepositoryProvider.value(value: status),
          RepositoryProvider.value(value: queue),
        ],
        child: MaterialApp(home: home),
      );
}

/// Echte Netzwerk-Antworten brauchen echte Zeit - pumpAndSettle allein
/// wartet darauf nicht.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpScreenTests();

  group('Detailseite', () {
    Future<Harness> open(WidgetTester tester) async {
      final h = Harness();
      late int id;
      await tester.runAsync(() async {
        id = h.backend.seedList('Wocheneinkauf', items: [
          {'name': 'Äpfel', 'quantity': 3.0, 'unit': 'PIECE'},
          {'name': 'Mehl', 'quantity': 50.0, 'unit': 'GRAM'},
          {'name': 'Milch', 'quantity': 0.5, 'unit': 'LITER', 'checked': true},
        ]);
        await h.repo.fetchShoppingLists();
      });
      final list = (await tester.runAsync(h.repo.cachedShoppingLists))!
          .firstWhere((l) => l.id == id);
      await tester.pumpWidget(h.app(ShoppingListDetailScreen(shoppingList: list)));
      await settle(tester);
      return h;
    }

    testScreen('zeigt Einträge als "3 Stück Äpfel", "50g Mehl"',
        (tester) async {
      await open(tester);

      expect(find.text('3 Stück Äpfel'), findsOneWidget);
      expect(find.text('50g Mehl'), findsOneWidget);
      expect(find.text('0,5l Milch'), findsOneWidget);
      // Das alte Format ist weg.
      expect(find.text('3.0 Stück'), findsNothing);
      expect(find.text('Äpfel'), findsNothing);
    });

    testScreen('Eintrag bearbeiten: Name, Menge und Einheit', (tester) async {
      final h = await open(tester);
      final listId = h.backend.lists.keys.single;

      await tester.tap(find.byTooltip('Bearbeiten').first);
      await tester.pumpAndSettle();
      expect(find.text('Produkt bearbeiten'), findsOneWidget);

      // Der Dialog ist mit den bisherigen Werten vorbelegt.
      final fields = find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField));
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, 'Äpfel');
      expect(tester.widget<TextField>(fields.at(1)).controller!.text, '3');

      await tester.enterText(fields.at(0), 'Birnen');
      await tester.enterText(fields.at(1), '1,5');
      await tester.tap(find.text('Stück').last);
      await tester.pumpAndSettle();
      // Die Auswahl öffnet bei "Stück"; "kg" steht ganz oben in der Liste.
      await tester.drag(find.byType(ListView).last, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('kg').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await settle(tester);

      expect(find.text('1,5kg Birnen'), findsOneWidget);
      expect(find.text('3 Stück Äpfel'), findsNothing);

      final server = h.backend.itemByName(listId, 'Birnen');
      expect(server['quantity'], 1.5);
      expect(server['unit'], 'KILOGRAM');
      expect(h.backend.itemNames(listId), ['Birnen', 'Mehl', 'Milch']);
    });

    testScreen('Liste umbenennen: Titel ändert sich sofort und beim Server',
        (tester) async {
      final h = await open(tester);
      final listId = h.backend.lists.keys.single;
      expect(find.text('Wocheneinkauf'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liste umbenennen'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'Samstag',
      );
      await tester.tap(find.text('Speichern'));
      await settle(tester);

      expect(find.text('Samstag'), findsOneWidget);
      expect(find.text('Wocheneinkauf'), findsNothing);
      expect(h.backend.lists[listId]!['title'], 'Samstag');
      // Die Einträge sind unverändert geblieben.
      expect(find.text('3 Stück Äpfel'), findsOneWidget);
    });

    testScreen('abhaken, hinzufügen und umbenennen ohne Verbindung',
        (tester) async {
      final h = await open(tester);
      final listId = h.backend.lists.keys.single;
      h.backend.offline = true;

      // Abhaken durch Antippen der Zeile.
      await tester.tap(find.text('50g Mehl'));
      await settle(tester);

      // Hinzufügen.
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Produkt hinzufügen'), findsOneWidget);
      final fields = find.descendant(
          of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(fields.at(0), 'Butter');
      await tester.enterText(fields.at(1), '2');
      await tester.tap(find.text('Hinzufügen'));
      await settle(tester);

      // Umbenennen.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Liste umbenennen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'Offline-Liste',
      );
      await tester.tap(find.text('Speichern'));
      await settle(tester);

      // Alles ist sofort sichtbar, obwohl nichts den Server erreicht hat.
      expect(find.text('Offline-Liste'), findsOneWidget);
      expect(find.text('2 Stück Butter'), findsOneWidget);
      expect(
        tester.widget<Checkbox>(find.descendant(
          of: find.ancestor(
              of: find.text('50g Mehl'), matching: find.byType(ListTile)),
          matching: find.byType(Checkbox),
        )).value,
        isTrue,
      );
      expect(h.queue.pendingCount, 3);
      expect(h.backend.lists[listId]!['title'], 'Wocheneinkauf');

      // Verbindung zurück: alles kommt an.
      h.backend.offline = false;
      await tester.runAsync(h.queue.flush);
      await settle(tester); // der Abgleich nach der Rückkehr der Verbindung
      expect(h.queue.pendingCount, 0);
      expect(h.backend.lists[listId]!['title'], 'Offline-Liste');
      expect(h.backend.itemByName(listId, 'Mehl')['checked'], isTrue);
      expect(h.backend.itemByName(listId, 'Butter')['quantity'], 2.0);
    });
  });

  group('Übersicht', () {
    testScreen('Liste über das Menü der Karte umbenennen', (tester) async {
      final h = Harness();
      late int id;
      await tester.runAsync(() async {
        id = h.backend.seedList('Wocheneinkauf');
      });

      await tester.pumpWidget(h.app(BlocProvider(
        create: (_) => ShoppingNavigatorCubit(repository: h.repo),
        child: const ShoppingListScreen(),
      )));
      await settle(tester);
      expect(find.text('Wocheneinkauf'), findsOneWidget);

      await tester.tap(find.byTooltip('Mehr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Umbenennen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'Grillabend',
      );
      await tester.tap(find.text('Speichern'));
      await settle(tester);

      expect(find.text('Grillabend'), findsOneWidget);
      expect(find.text('Wocheneinkauf'), findsNothing);
      expect(h.backend.lists[id]!['title'], 'Grillabend');
    });

    testScreen('ohne Verbindung erscheinen die gespeicherten Listen, kein Dauer-Ladekreis',
        (tester) async {
      final h = Harness();
      await tester.runAsync(() async {
        h.backend.seedList('Wocheneinkauf');
        await h.repo.fetchShoppingLists();
      });
      h.backend.offline = true;

      await tester.pumpWidget(h.app(BlocProvider(
        create: (_) => ShoppingNavigatorCubit(repository: h.repo),
        child: const ShoppingListScreen(),
      )));
      await settle(tester);

      expect(find.text('Wocheneinkauf'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testScreen('ohne Verbindung und ohne Daten: Hinweis mit "Erneut versuchen"',
        (tester) async {
      final h = Harness()..backend.offline = true;

      await tester.pumpWidget(h.app(BlocProvider(
        create: (_) => ShoppingNavigatorCubit(repository: h.repo),
        child: const ShoppingListScreen(),
      )));
      await settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Erneut versuchen'), findsOneWidget);

      h.backend.offline = false;
      h.backend.seedList('Wocheneinkauf');
      await tester.tap(find.text('Erneut versuchen'));
      await settle(tester);
      expect(find.text('Wocheneinkauf'), findsOneWidget);
    });
  });
}
