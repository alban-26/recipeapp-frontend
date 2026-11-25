import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipeapp_frontend/offline/ConnectionStatus.dart';
import 'package:recipeapp_frontend/offline/LocalStore.dart';
import 'package:recipeapp_frontend/offline/OfflineBanner.dart';
import 'package:recipeapp_frontend/offline/SyncQueue.dart';
import 'package:recipeapp_frontend/offline/SyncScheduler.dart';
import 'package:recipeapp_frontend/recipe/detail_screen/RecipeScreen.dart';
import 'package:recipeapp_frontend/recipe/domain/CookingInstruction.dart';
import 'package:recipeapp_frontend/recipe/domain/Recipe.dart';
import 'package:recipeapp_frontend/recipe/domain/RecipeIngredient.dart';

import 'support/screen_testing.dart';

void main() {
  setUpScreenTests();

  group('Rezeptansicht', () {
    const mehl = RecipeIngredient(
        id: 'a', name: 'Mehl', category: 'DRY_GOODS', quantity: 50, unit: 'g');
    const aepfel = RecipeIngredient(
        id: 'b', name: 'Äpfel', category: 'FRUITS', quantity: 3, unit: 'Stück');
    const salz = RecipeIngredient(
        id: 'c', name: 'Salz', category: 'SPICES', quantity: 0, unit: 'g');
    const recipe = Recipe(
      id: 1,
      name: 'Apfelkuchen',
      portions: 4,
      duration: Duration(minutes: 45),
      tags: [],
      recipeIngredients: [aepfel, mehl, salz],
      cookingInstructions: [
        CookingInstruction(instruction: 'Verrühren', recipeIngredients: [mehl]),
      ],
    );

    // Hoch genug, dass Zutaten UND Zubereitung aufgebaut werden (die Liste
    // baut nur, was sichtbar ist).
    Future<void> open(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(home: RecipeScreen(recipe: recipe)));
      await tester.pumpAndSettle();
    }

    testWidgets('Zutaten im Format "3 Stück Äpfel", "50g Mehl"', (tester) async {
      await open(tester);

      expect(find.text('3 Stück Äpfel'), findsOneWidget);
      // Einmal in der Zutatenliste, einmal als Marke am Zubereitungsschritt.
      expect(find.text('50g Mehl'), findsNWidgets(2));
      expect(find.text('Salz'), findsOneWidget);
      expect(find.textContaining('3.0'), findsNothing);
      expect(find.textContaining('50.0'), findsNothing);
    });

    testWidgets('Mengen folgen der Portionenzahl - ohne Zahlensalat',
        (tester) async {
      await open(tester);

      await tester.tap(find.byIcon(Icons.remove_circle_outline)); // 4 -> 3
      await tester.pumpAndSettle();

      expect(find.text('2,25 Stück Äpfel'), findsOneWidget);
      expect(find.text('37,5g Mehl'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.tap(find.byIcon(Icons.add_circle_outline)); // -> 5
      await tester.pumpAndSettle();

      expect(find.text('3,75 Stück Äpfel'), findsOneWidget);
      expect(find.text('62,5g Mehl'), findsOneWidget);
    });
  });

  group('Offline-Hinweis', () {
    late ConnectionStatus status;
    late SyncQueue queue;
    var syncRequests = 0;

    Future<void> pump(WidgetTester tester) async {
      status = ConnectionStatus();
      queue = SyncQueue(store: MemoryLocalStore());
      await tester.runAsync(queue.load);
      syncRequests = 0;
      final scheduler = SyncScheduler(
        queue: queue,
        status: status,
        hasSession: () async {
          syncRequests++;
          return false;
        },
        probe: () async {},
      );
      await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: status),
          RepositoryProvider.value(value: queue),
          RepositoryProvider.value(value: scheduler),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: Column(children: [Spacer(), OfflineBanner()]),
          ),
        ),
      ));
    }

    testWidgets('online und alles übertragen: nichts zu sehen', (tester) async {
      await pump(tester);
      expect(find.byIcon(Icons.cloud_off), findsNothing);
      expect(find.textContaining('Offline'), findsNothing);
    });

    testWidgets('erscheint ohne Verbindung und verschwindet wieder',
        (tester) async {
      await pump(tester);

      status.reportFailure(const SocketException('Network is unreachable'));
      await tester.pumpAndSettle();
      expect(find.text('Offline – gespeicherte Daten werden angezeigt'),
          findsOneWidget);

      status.reportSuccess();
      await tester.pumpAndSettle();
      expect(find.textContaining('Offline'), findsNothing);
    });

    testWidgets('nennt die Zahl wartender Änderungen; Antippen versucht es erneut',
        (tester) async {
      await pump(tester);
      queue.register('op', (op) async => throw const SocketException('offline'));

      status.reportFailure(const SocketException('offline'));
      queue.enqueue('op', {});
      await tester.runAsync(queue.flush);
      await tester.pumpAndSettle();
      expect(find.text('Offline – 1 Änderung wird nachgereicht'), findsOneWidget);

      queue.enqueue('op', {});
      await tester.runAsync(queue.flush);
      await tester.pumpAndSettle();
      expect(find.text('Offline – 2 Änderungen werden nachgereicht'),
          findsOneWidget);

      await tester.tap(find.byType(OfflineBanner));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(syncRequests, 1);
    });

    testWidgets('online blitzt bei einer normalen Änderung nichts auf',
        (tester) async {
      await pump(tester);
      queue.register('op', (op) async {});

      queue.enqueue('op', {});
      await tester.pump();
      expect(find.byType(Icon), findsNothing);

      await tester.runAsync(queue.flush);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('online, aber Änderung bleibt hängen: nach kurzer Zeit ein Hinweis',
        (tester) async {
      await pump(tester);
      queue.register('op', (op) async => throw StateError('retry'));
      // 401 o.ä. würde liegen bleiben - hier mit fehlendem Handler nachgestellt.
      queue.enqueue('unbekannt', {});
      await tester.runAsync(queue.flush);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('nicht übertragen'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('1 Änderung noch nicht übertragen'), findsOneWidget);
    });
  });
}
