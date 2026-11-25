import 'dart:async';
import 'dart:convert';

import 'package:recipeapp_frontend/StorageRepository.dart';

import '../api/BaseApiClient.dart';
import '../offline/ConnectionStatus.dart';
import '../offline/LocalStore.dart';
import 'domain/Recipe.dart';
import 'domain/RecipePage.dart';

class RecipeApiClient extends BaseApiClient {
  final StorageRepository storageRepository;

  RecipeApiClient(
      {required super.dio,
      required super.secureStorage,
      required super.baseUrl,
      required this.storageRepository});

  String imageUrl(int recipeId) => '$baseUrl/recipes/$recipeId/image';

  /// [withImages] = false laesst die Bilder weg (fuer den Abgleich im
  /// Hintergrund, der sie einzeln und nur bei Bedarf nachlaedt).
  Future<RecipePage> getRecipes({int page = 0, int size = 20, String? searchQuery, List<String>? tags, bool withImages = true}) async {
    final response = await dio.get(
      '$baseUrl/recipes',
      queryParameters: {
        'page': page,
        'size': size,
        if (searchQuery != null && searchQuery.isNotEmpty) 'searchQuery': searchQuery,
        if (tags != null && tags.isNotEmpty) 'tags': tags,
      },
    );

    if (response.statusCode == 204 || response.data == null || response.data == "") {
      return RecipePage.empty(page: page, size: size);
    }

    final data = response.data as Map<String, dynamic>;
    final rawContent = (data['content'] as List? ?? []);

    final recipes = rawContent
        .map((e) => Recipe.fromJson(e)) // Create basic recipes without images
        .toList();

    final recipesWithImages = !withImages
        ? recipes
        : await Future.wait(recipes.map((recipe) async =>
            await recipe.withImage(storageRepository, imageUrl(recipe.id))));

    return RecipePage(
      content: recipesWithImages,
      page: data['page'] as int,
      size: data['size'] as int,
      totalPages: data['totalPages'] as int,
      totalElements: data['totalElements'] as int,
      last: data['last'] as bool,
    );
  }

  Future<Recipe> getRecipe(String id) async {
    final response = await dio.get('$baseUrl/recipes/$id');
    return Recipe.fromJson(response.data);
  }

  Future<List<String>> getTags() async {
    final response = await dio.get('$baseUrl/recipes/tags');

    if (response.statusCode == 204 || response.data == null) {
      return [];
    }

    return (response.data as List<dynamic>)
        .map((e) => e.toString())
        .toList();
  }

  Future<int?> deleteRecipe(String id) async {
    final response = await dio.delete('$baseUrl/recipes/$id');
    // Ensure response data is a Map and contains 'id'
    if (response.statusCode != null) {
      return response.statusCode;
    } else {
      throw Exception("Invalid response: ${response.data}");
    }
  }

  Future<Recipe> updateRecipe(
      Recipe recipe,
      ) async {
    final response = await dio.put(
      '$baseUrl/recipes',
      data: recipe.toJson(),
    );

    return Recipe.fromJson(response.data);
  }

  Future<int> createRecipe(Recipe recipe) async {
    final response = await dio.post(
      '$baseUrl/recipes',
      data: recipe.toJson(),
    );

    // Ensure response data is a Map and contains 'id'
    if (response.data != null) {
      return response.data as int;
    } else {
      throw Exception("Invalid response: ${response.data}");
    }
  }

  Future<Map<String, List<String>>> loadIngredients() async {
    final response = await dio.get('$baseUrl/recipes/ingredients');

    List<dynamic> data = [];
    if (response.data != null && response.data != '' && response.data != '[]') {
      data = response.data is String
          ? jsonDecode(response.data)
          : response.data;
    }

    final Map<String, List<String>> result = {};
    for (final item in data) {
      final category = item['category'] as String;
      final name = item['name'] as String;
      result.putIfAbsent(category, () => []).add(name);
    }

    return result;
  }

}

/// Rezepte. Online wie bisher direkt vom Server; alles Geladene wird
/// zusaetzlich lokal abgelegt, sodass Liste, Suche, Tag-Filter und
/// Detailansicht auch ohne Verbindung funktionieren.
///
/// Anlegen, Aendern und Loeschen brauchen weiterhin eine Verbindung.
class RecipeRepository {
  static const _cacheKey = 'recipes';
  static const _ingredientsKey = 'recipe_ingredients';

  /// So oft wird hoechstens der komplette Bestand im Hintergrund abgeglichen.
  static const _fullSyncInterval = Duration(hours: 6);

  final RecipeApiClient apiClient;
  final LocalStore store;

  /// Alle bekannten Rezepte (ohne Bilder). null = noch nie etwas gespeichert.
  List<Recipe>? _recipes;
  DateTime? _lastFullSync;
  bool _loaded = false;
  Future<void>? _loading;
  bool _fullSyncRunning = false;

  /// Zaehlt Aenderungen am lokalen Bestand; schuetzt davor, dass ein laenger
  /// laufender Abgleich neuere Daten ueberschreibt.
  int _generation = 0;

  RecipeRepository({required this.apiClient, required this.store});

  // --- lokaler Bestand ------------------------------------------------------

  Future<void> _ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    final generation = _generation;
    List<Recipe>? loaded;
    DateTime? syncedAt;
    try {
      final raw = await store.readJson(_cacheKey);
      if (raw is Map && raw['recipes'] is List) {
        loaded = (raw['recipes'] as List)
            .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final stamp = raw['fullSyncAt'];
        if (stamp is String) syncedAt = DateTime.tryParse(stamp);
      }
    } catch (e) {
      print('[RecipeRepository] Lokale Rezepte nicht lesbar: $e');
    }
    if (generation == _generation) {
      _recipes = loaded;
      _lastFullSync = syncedAt;
      _loaded = true;
    }
    _loading = null;
  }

  void _persist() {
    final recipes = _recipes;
    if (recipes == null) return;
    store.writeJson(_cacheKey, {
      'fullSyncAt': _lastFullSync?.toIso8601String(),
      'recipes': recipes.map((r) => r.toJson()).toList(),
    });
  }

  /// Traegt Rezepte ein bzw. ersetzt vorhandene mit derselben ID.
  Future<void> _upsert(Iterable<Recipe> recipes) async {
    await _ensureLoaded();
    final byId = <int, Recipe>{
      for (final r in _recipes ?? const <Recipe>[]) r.id: r,
    };
    for (final recipe in recipes) {
      byId[recipe.id] = recipe.copyWithoutImage();
    }
    _recipes = byId.values.toList();
    _generation++;
    _persist();
  }

  /// Ersetzt den kompletten Bestand - danach sind auch Rezepte verschwunden,
  /// die auf einem anderen Geraet geloescht wurden.
  void _replaceAll(List<Recipe> recipes) {
    final ids = recipes.map((r) => r.id).toSet();
    for (final old in _recipes ?? const <Recipe>[]) {
      if (!ids.contains(old.id)) {
        apiClient.storageRepository
            .forgetCachedImage(apiClient.imageUrl(old.id));
      }
    }
    _recipes = recipes.map((r) => r.copyWithoutImage()).toList();
    _lastFullSync = DateTime.now();
    _generation++;
    _persist();
  }

  /// Verwirft den lokalen Bestand im Speicher (Logout / Nutzerwechsel).
  void resetCache() {
    _generation++;
    _recipes = null;
    _lastFullSync = null;
    _loaded = false;
    _loading = null;
  }

  static bool _matches(Recipe recipe, String query, List<String> tags) {
    // Wie der Server: Name enthaelt den Suchbegriff (ohne Gross-/Klein-
    // schreibung) UND das Rezept traegt ALLE gewaehlten Tags.
    if (query.isNotEmpty &&
        !recipe.name.toLowerCase().contains(query.toLowerCase())) {
      return false;
    }
    for (final tag in tags) {
      if (!recipe.tags.contains(tag)) return false;
    }
    return true;
  }

  /// Eine Seite aus dem lokalen Bestand - gleiche Sortierung (Name) und
  /// gleiche Seitenlogik wie der Server. null, wenn noch nie etwas
  /// gespeichert wurde.
  Future<RecipePage?> cachedRecipes({
    int page = 0,
    int size = 20,
    String? query,
    List<String>? tags,
  }) async {
    await _ensureLoaded();
    final all = _recipes;
    if (all == null) return null;

    final matching = all
        .where((r) => _matches(r, query ?? '', tags ?? const []))
        .toList()
      ..sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });

    final start = page * size;
    final slice = start >= matching.length
        ? <Recipe>[]
        : matching.sublist(
            start,
            start + size > matching.length ? matching.length : start + size,
          );

    final withImages = await Future.wait(slice.map((recipe) =>
        recipe.withImage(
          apiClient.storageRepository,
          apiClient.imageUrl(recipe.id),
          cacheOnly: true,
        )));

    return RecipePage(
      content: withImages,
      page: page,
      size: size,
      totalPages: (matching.length / size).ceil(),
      totalElements: matching.length,
      last: start + size >= matching.length,
    );
  }

  // --- Lesen ----------------------------------------------------------------

  Future<RecipePage> fetchRecipes({int page = 0, int size = 20, String? query, List<String>? tags}) async {
    final unfiltered =
        (query == null || query.isEmpty) && (tags == null || tags.isEmpty);
    final RecipePage result;
    try {
      result = await apiClient.getRecipes(page: page, size: size, searchQuery: query, tags: tags);
    } catch (e) {
      if (!isConnectivityFailure(e)) rethrow;
      final local = await cachedRecipes(page: page, size: size, query: query, tags: tags);
      if (local == null) rethrow;
      return local;
    }

    await _ensureLoaded();
    if (unfiltered && page == 0 && result.last) {
      // Die erste Seite ist schon alles - der Bestand ist damit komplett.
      _replaceAll(result.content);
    } else {
      await _upsert(result.content);
      if (unfiltered && page == 0) _syncAllInBackground(result);
    }
    return result;
  }

  /// Holt die restlichen Seiten (und fehlende Bilder), damit offline ALLE
  /// Rezepte da sind und nicht nur die, die zufaellig schon angezeigt wurden.
  void _syncAllInBackground(RecipePage firstPage) {
    if (_fullSyncRunning) return;
    final last = _lastFullSync;
    if (last != null && DateTime.now().difference(last) < _fullSyncInterval) {
      return;
    }
    _fullSyncRunning = true;
    _syncAll(firstPage).catchError((Object e) {
      // Offline o.ae. - beim naechsten Laden der Liste wieder.
    }).whenComplete(() => _fullSyncRunning = false);
  }

  Future<void> _syncAll(RecipePage firstPage) async {
    final generation = _generation;
    final all = <Recipe>[...firstPage.content];
    var page = firstPage;
    // Obergrenze, falls der Server nie "last" meldet.
    for (var guard = 0; !page.last && guard < 500; guard++) {
      page = await apiClient.getRecipes(
        page: page.page + 1,
        size: firstPage.size,
        withImages: false,
      );
      all.addAll(page.content);
    }

    if (generation == _generation) {
      _replaceAll(all);
    } else {
      // Zwischendurch wurde lokal etwas geaendert: nur ergaenzen.
      await _upsert(all);
    }

    // Bilder einzeln und nur, wenn sie noch fehlen.
    final storage = apiClient.storageRepository;
    for (final recipe in all) {
      final url = apiClient.imageUrl(recipe.id);
      if (await storage.hasCachedImage(url)) continue;
      await storage.loadImage(url);
    }
  }

  Future<List<String>> fetchTags() async {
    try {
      return await apiClient.getTags();
    } catch (e) {
      if (!isConnectivityFailure(e)) rethrow;
      await _ensureLoaded();
      final all = _recipes;
      if (all == null) rethrow;
      final tags = <String>{for (final r in all) ...r.tags}.toList()..sort();
      return tags;
    }
  }

  Future<Recipe> fetchRecipe(String recipeId) async {
    try {
      final recipe = await apiClient.getRecipe(recipeId);
      await _upsert([recipe]);
      return recipe;
    } catch (e) {
      if (!isConnectivityFailure(e)) rethrow;
      await _ensureLoaded();
      for (final recipe in _recipes ?? const <Recipe>[]) {
        if (recipe.id.toString() == recipeId) return recipe;
      }
      rethrow;
    }
  }

  // --- Schreiben (nur mit Verbindung) ---------------------------------------

  Future<Recipe> updateRecipe(Recipe recipe) async {
    final updated = await apiClient.updateRecipe(recipe);
    await _upsert([updated]);
    return updated;
  }

  Future<int> addRecipe(Recipe recipe) async {
    final id = await apiClient.createRecipe(recipe);
    await _upsert([recipe.copyWith(id: id)]);
    return id;
  }

  Future<int?> removeRecipe(int recipeId) async {
    final status = await apiClient.deleteRecipe(recipeId.toString());
    await _ensureLoaded();
    final all = _recipes;
    if (all != null) {
      _recipes = all.where((r) => r.id != recipeId).toList();
      _generation++;
      _persist();
    }
    await apiClient.storageRepository
        .forgetCachedImage(apiClient.imageUrl(recipeId));
    return status;
  }

  /// Eigene Zutaten fuer die Vorschlagsliste. Ohne Verbindung der zuletzt
  /// gespeicherte Stand - zur Not leer, damit das Formular trotzdem aufgeht.
  Future<Map<String, List<String>>> loadIngredients() async {
    try {
      final ingredients = await apiClient.loadIngredients();
      store.writeJson(_ingredientsKey, ingredients);
      return ingredients;
    } catch (e) {
      if (!isConnectivityFailure(e)) rethrow;
      try {
        final raw = await store.readJson(_ingredientsKey);
        if (raw is Map) {
          return raw.map((key, value) => MapEntry(
                key.toString(),
                List<String>.from(value as List),
              ));
        }
      } catch (_) {}
      return {};
    }
  }
}
