import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipeapp_frontend/StorageRepository.dart';
import 'package:recipeapp_frontend/meal_plan/MealPlanApiClient.dart';
import 'package:recipeapp_frontend/meal_plan/MealPlanRepository.dart';
import 'package:recipeapp_frontend/meal_plan/domain/DailyMealPlan.dart';
import 'package:recipeapp_frontend/meal_plan/domain/Meal.dart';
import 'package:recipeapp_frontend/meal_plan/domain/MealPlan.dart';
import 'package:recipeapp_frontend/meal_plan/domain/Mealtime.dart';
import 'package:recipeapp_frontend/meal_plan/domain/RecipeRef.dart';
import 'package:recipeapp_frontend/offline/ConnectionStatus.dart';
import 'package:recipeapp_frontend/offline/LocalStore.dart';
import 'package:recipeapp_frontend/recipe/RecipeRepository.dart';

const _base = 'http://test.local';

/// Nachgestellter recipe- und meal-plan-Service (Suche, Tag-Filter und
/// Sortierung wie in RecipeMapper.selectRecipesByUser).
class Server implements HttpClientAdapter {
  bool offline = false;
  int? failWith;
  final List<String> log = [];

  final List<Map<String, dynamic>> recipes = [];
  final Map<int, List<int>> images = {};
  List<Map<String, dynamic>> mealPlans = [];

  void addRecipe(int id, String name,
      {List<String> tags = const [], bool image = true}) {
    recipes.add({
      'id': id,
      'name': name,
      'portions': 4,
      'duration': 'PT0H30M0S',
      'tags': tags,
      'recipeIngredients': [
        {'id': 'i$id', 'name': 'Mehl', 'category': 'DRY_GOODS', 'quantity': 50.0, 'unit': 'g'},
      ],
      'cookingInstructions': [
        {'instruction': 'Rühren', 'recipeIngredients': []},
      ],
    });
    if (image) images[id] = [0xFF, 0xD8, id % 256];
  }

  ResponseBody _json(int status, Object? body) => ResponseBody.fromString(
        body == null ? '' : jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    await Future<void>.delayed(Duration.zero);
    if (offline) throw const SocketException('Network is unreachable');
    final uri = options.uri;
    log.add('${options.method} ${uri.path}');
    if (failWith != null) return _json(failWith!, {'message': 'boom'});

    final segments = uri.pathSegments;

    if (uri.path == '/recipes' && options.method == 'GET') {
      final page = int.parse(uri.queryParameters['page'] ?? '0');
      final size = int.parse(uri.queryParameters['size'] ?? '20');
      final query = (uri.queryParameters['searchQuery'] ?? '').toLowerCase();
      final tags = uri.queryParametersAll['tags'] ?? const <String>[];
      final matching = recipes
          .where((r) =>
              (r['name'] as String).toLowerCase().contains(query) &&
              tags.every((t) => (r['tags'] as List).contains(t)))
          .toList()
        ..sort((a, b) => (a['name'] as String)
            .toLowerCase()
            .compareTo((b['name'] as String).toLowerCase()));
      final start = page * size;
      final end = start + size > matching.length ? matching.length : start + size;
      return _json(200, {
        'content': start >= matching.length ? [] : matching.sublist(start, end),
        'page': page,
        'size': size,
        'totalElements': matching.length,
        'totalPages': (matching.length / size).ceil(),
        'last': end >= matching.length,
      });
    }
    if (uri.path == '/recipes/tags') {
      final tags = <String>{
        for (final r in recipes) ...(r['tags'] as List).cast<String>()
      };
      return _json(200, tags.toList());
    }
    if (uri.path == '/recipes/ingredients') {
      return _json(200, [
        {'name': 'Dinkelmehl', 'category': 'DRY_GOODS'},
      ]);
    }
    if (segments.length == 3 && segments[0] == 'recipes' && segments[2] == 'image') {
      final bytes = images[int.parse(segments[1])];
      if (bytes == null) return _json(404, {'message': 'Recipe image not found'});
      return ResponseBody.fromBytes(bytes, 200);
    }
    if (segments.length == 2 && segments[0] == 'recipes' && options.method == 'DELETE') {
      recipes.removeWhere((r) => r['id'].toString() == segments[1]);
      return _json(200, null);
    }

    if (uri.path == '/mealPlans' && options.method == 'GET') {
      if (mealPlans.isEmpty) return _json(204, null);
      return _json(200, mealPlans);
    }
    if (uri.path == '/mealPlans' && options.method == 'POST') {
      final plan = Map<String, dynamic>.from(options.data as Map)..['id'] = 77;
      mealPlans = [...mealPlans, plan];
      return _json(201, plan);
    }
    if (uri.path == '/mealPlans/recipes') {
      return _json(200, [
        for (final r in recipes) {'id': r['id'], 'name': r['name']}
      ]);
    }
    return _json(404, {'message': 'not found'});
  }

  @override
  void close({bool force = false}) {}
}

class Harness {
  final Server server = Server();
  final LocalStore store = MemoryLocalStore();
  late ConnectionStatus status;
  late RecipeRepository recipes;
  late MealPlanRepository mealPlans;

  Harness() {
    restart();
  }

  /// Neustart der App: neue Objekte, gleiche gespeicherte Daten.
  void restart() {
    status = ConnectionStatus();
    final dio = Dio()
      ..httpClientAdapter = server
      ..interceptors.add(ConnectivityInterceptor(status));
    const secure = FlutterSecureStorage();
    final storage = StorageRepository(
        dio: dio, secureStorage: secure, baseUrl: _base, imageCache: store);
    recipes = RecipeRepository(
      apiClient: RecipeApiClient(
          dio: dio,
          secureStorage: secure,
          baseUrl: _base,
          storageRepository: storage),
      store: store,
    );
    mealPlans = MealPlanRepository(
      apiClient: MealPlanApiClient(
          dio: dio,
          secureStorage: secure,
          baseUrl: _base,
          storageRepository: storage),
      store: store,
    );
  }

  Future<void> settle() async {
    for (var i = 0; i < 50; i++) {
      await pumpEventQueue();
    }
  }
}

void main() {
  group('Rezepte', () {
    test('einmal online geladen - danach auch offline da, samt Bild und Zutaten',
        () async {
      final h = Harness();
      h.server.addRecipe(1, 'Apfelkuchen', tags: ['backen']);
      h.server.addRecipe(2, 'Zucchinisuppe', image: false);
      await h.recipes.fetchRecipes();

      h.restart();
      h.server.offline = true;
      final page = await h.recipes.fetchRecipes();

      expect(page.content.map((r) => r.name), ['Apfelkuchen', 'Zucchinisuppe']);
      expect(page.last, isTrue);
      expect(page.content[0].image, [0xFF, 0xD8, 1]);
      expect(page.content[1].image, isNull);
      expect(page.content[0].tags, ['backen']);
      expect(page.content[0].recipeIngredients.single.name, 'Mehl');
      expect(page.content[0].cookingInstructions.single.instruction, 'Rühren');
      expect(page.content[0].duration, const Duration(minutes: 30));
      expect(h.status.isOffline, isTrue);
    });

    test('offline sind ALLE Rezepte da, nicht nur die erste angezeigte Seite',
        () async {
      final h = Harness();
      for (var i = 1; i <= 45; i++) {
        h.server.addRecipe(i, 'Rezept ${i.toString().padLeft(2, '0')}');
      }
      // Der Nutzer sieht nur die erste Seite ...
      final first = await h.recipes.fetchRecipes(page: 0, size: 20);
      expect(first.content, hasLength(20));
      expect(first.last, isFalse);
      await h.settle(); // ... der Rest wird im Hintergrund geholt.

      h.server.offline = true;
      final p0 = await h.recipes.fetchRecipes(page: 0, size: 20);
      final p1 = await h.recipes.fetchRecipes(page: 1, size: 20);
      final p2 = await h.recipes.fetchRecipes(page: 2, size: 20);

      expect(p0.totalElements, 45);
      expect([p0.last, p1.last, p2.last], [false, false, true]);
      expect(p2.content, hasLength(5));
      expect(p0.content.first.name, 'Rezept 01');
      expect(p2.content.last.name, 'Rezept 45');
      // Auch die Bilder der nie angezeigten Rezepte liegen lokal vor.
      expect(p2.content.last.image, [0xFF, 0xD8, 45]);
    });

    test('Suche und Tag-Filter liefern offline dasselbe wie der Server',
        () async {
      final h = Harness();
      h.server.addRecipe(1, 'Apfelkuchen', tags: ['backen', 'vegetarisch']);
      h.server.addRecipe(2, 'Apfelmus', tags: ['vegetarisch']);
      h.server.addRecipe(3, 'Bratapfel', tags: ['backen']);
      h.server.addRecipe(4, 'Gulasch');
      await h.recipes.fetchRecipes();

      Future<List<String>> search({String? query, List<String>? tags}) async =>
          (await h.recipes.fetchRecipes(query: query, tags: tags))
              .content
              .map((r) => r.name)
              .toList();

      final online = [
        await search(query: 'apfel'),
        await search(tags: ['backen']),
        await search(tags: ['backen', 'vegetarisch']),
        await search(query: 'APFEL', tags: ['vegetarisch']),
        await search(query: 'gibtsnicht'),
      ];

      h.server.offline = true;
      final offline = [
        await search(query: 'apfel'),
        await search(tags: ['backen']),
        await search(tags: ['backen', 'vegetarisch']),
        await search(query: 'APFEL', tags: ['vegetarisch']),
        await search(query: 'gibtsnicht'),
      ];

      expect(offline, online);
      expect(offline[0], ['Apfelkuchen', 'Apfelmus', 'Bratapfel']);
      expect(offline[2], ['Apfelkuchen']);
      expect(offline[4], isEmpty);
    });

    test('auf einem anderen Gerät Gelöschtes verschwindet beim nächsten Abgleich',
        () async {
      final h = Harness();
      h.server.addRecipe(1, 'Apfelkuchen');
      h.server.addRecipe(2, 'Gulasch');
      await h.recipes.fetchRecipes();

      h.server.recipes.removeWhere((r) => r['id'] == 2);
      await h.recipes.fetchRecipes();

      h.server.offline = true;
      final page = await h.recipes.fetchRecipes();
      expect(page.content.map((r) => r.name), ['Apfelkuchen']);
    });

    test('nach dem Löschen ist das Rezept auch lokal weg', () async {
      final h = Harness();
      h.server.addRecipe(1, 'Apfelkuchen');
      h.server.addRecipe(2, 'Gulasch');
      await h.recipes.fetchRecipes();

      await h.recipes.removeRecipe(2);

      h.server.offline = true;
      expect((await h.recipes.fetchRecipes()).content.map((r) => r.name),
          ['Apfelkuchen']);
    });

    test('Tags und Zutatenvorschläge gibt es auch offline', () async {
      final h = Harness();
      h.server.addRecipe(1, 'Apfelkuchen', tags: ['backen', 'süß']);
      h.server.addRecipe(2, 'Gulasch', tags: ['deftig']);
      await h.recipes.fetchRecipes();
      await h.recipes.loadIngredients();

      h.server.offline = true;
      expect(await h.recipes.fetchTags(), ['backen', 'deftig', 'süß']);
      expect(await h.recipes.loadIngredients(), {
        'DRY_GOODS': ['Dinkelmehl'],
      });
    });

    test('ohne Verbindung und ohne gespeicherte Rezepte: klarer Fehler statt leerer Liste',
        () async {
      final h = Harness()..server.offline = true;

      expect(await h.recipes.cachedRecipes(), isNull);
      await expectLater(
          h.recipes.fetchRecipes(), throwsA(predicate(isConnectivityFailure)));
      // Das Formular "Rezept erstellen" soll trotzdem aufgehen.
      expect(await h.recipes.loadIngredients(), isEmpty);
    });

    test('ein echter Serverfehler wird nicht als "offline" kaschiert', () async {
      final h = Harness();
      h.server.addRecipe(1, 'Apfelkuchen');
      await h.recipes.fetchRecipes();

      h.server.failWith = 500;
      await expectLater(
        h.recipes.fetchRecipes(),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 500)),
      );
      expect(h.status.isOffline, isFalse);
    });

    test('ist der Server nur hinter dem Gateway weg (503), gibt es die Kopie',
        () async {
      final h = Harness();
      h.server.addRecipe(1, 'Apfelkuchen');
      await h.recipes.fetchRecipes();

      h.server.failWith = 503;
      final page = await h.recipes.fetchRecipes();
      expect(page.content.single.name, 'Apfelkuchen');
      expect(h.status.isOffline, isTrue);
    });
  });

  group('Essenspläne', () {
    MealPlan plan() => MealPlan(
          id: 0,
          startDate: DateTime(2026, 11, 23),
          endDate: DateTime(2026, 11, 24),
          dailyMealPlans: [
            DailyMealPlan(
              id: 1,
              date: DateTime(2026, 11, 23),
              meals: const {
                Mealtime.DINNER: [
                  Meal(recipe: RecipeRef(id: 1, name: 'Apfelkuchen'), servings: 2),
                ],
              },
            ),
          ],
        );

    test('gespeicherte Pläne und Rezeptauswahl sind offline da', () async {
      final h = Harness();
      h.server.addRecipe(1, 'Apfelkuchen');
      await h.mealPlans.addMealPlan(plan());
      await h.mealPlans.fetchMealPlans();
      await h.mealPlans.getAllRecipes();

      h.restart();
      h.server.offline = true;

      final plans = await h.mealPlans.fetchMealPlans();
      expect(plans.single.id, 77);
      expect(plans.single.dailyMealPlans.single.meals[Mealtime.DINNER]!.single
          .recipe.name, 'Apfelkuchen');
      expect((await h.mealPlans.getAllRecipes()).single.name, 'Apfelkuchen');
      expect(await h.mealPlans.cachedMealPlans(), hasLength(1));
    });

    test('Speichern ohne Verbindung meldet den Fehler, statt ihn zu verschlucken',
        () async {
      final h = Harness()..server.offline = true;

      await expectLater(h.mealPlans.addMealPlan(plan()),
          throwsA(predicate(isConnectivityFailure)));
      expect(await h.mealPlans.cachedMealPlans(), isNull);
    });
  });
}
