import '../offline/ConnectionStatus.dart';
import '../offline/LocalStore.dart';
import 'MealPlanApiClient.dart';
import 'domain/DailyMealPlan.dart';
import 'domain/MealPlan.dart';
import 'domain/RecipeRef.dart';

/// Essensplaene. Lesen funktioniert auch ohne Verbindung (zuletzt gespeicherter
/// Stand); Anlegen, Aendern und Loeschen brauchen den Server.
class MealPlanRepository {
  static const _plansKey = 'meal_plans';
  static const _recipesKey = 'meal_plan_recipes';

  final MealPlanApiClient apiClient;
  final LocalStore store;

  /// null = noch nie gespeichert.
  List<MealPlan>? _plans;
  bool _loaded = false;
  Future<void>? _loading;
  int _generation = 0;

  MealPlanRepository({required this.apiClient, required this.store});

  Future<void> _ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    final generation = _generation;
    List<MealPlan>? loaded;
    try {
      final raw = await store.readJson(_plansKey);
      if (raw is List) {
        loaded = raw
            .map((e) => MealPlan.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      print('[MealPlanRepository] Lokale Essensplaene nicht lesbar: $e');
    }
    if (generation == _generation) {
      _plans = loaded;
      _loaded = true;
    }
    _loading = null;
  }

  void _setPlans(List<MealPlan> plans) {
    _plans = plans;
    _generation++;
    store.writeJson(_plansKey, plans.map((p) => p.toJson()).toList());
  }

  /// Traegt einen Plan ein bzw. ersetzt den mit derselben ID.
  Future<void> _upsert(MealPlan plan) async {
    await _ensureLoaded();
    final plans = List<MealPlan>.of(_plans ?? const []);
    final index = plans.indexWhere((p) => p.id == plan.id);
    if (index >= 0) {
      plans[index] = plan;
    } else {
      plans.add(plan);
    }
    _setPlans(plans);
  }

  /// Verwirft den lokalen Stand im Speicher (Logout / Nutzerwechsel).
  void resetCache() {
    _generation++;
    _plans = null;
    _loaded = false;
    _loading = null;
  }

  /// Rezepte zur Auswahl im Essensplan. Ohne Verbindung der zuletzt
  /// gespeicherte Stand.
  Future<List<RecipeRef>> getAllRecipes() async {
    try {
      final recipes = await apiClient.getRecipes();
      store.writeJson(_recipesKey, recipes.map((r) => r.toJson()).toList());
      return recipes;
    } catch (e) {
      if (!isConnectivityFailure(e)) rethrow;
      final raw = await store.readJson(_recipesKey);
      if (raw is! List) rethrow;
      return raw
          .map((e) => RecipeRef.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  }

  /// Der lokale Stand ohne Netzwerk - oder null, wenn es noch keinen gibt.
  Future<List<MealPlan>?> cachedMealPlans() async {
    await _ensureLoaded();
    final plans = _plans;
    return plans == null ? null : List<MealPlan>.of(plans);
  }

  Future<List<MealPlan>> fetchMealPlans() async {
    await _ensureLoaded();
    final generation = _generation;
    try {
      final plans = await apiClient.getMealPlans();
      // Nicht ueberschreiben, wenn waehrend der Abfrage gespeichert wurde.
      if (generation == _generation) _setPlans(plans);
      return plans;
    } catch (e) {
      if (!isConnectivityFailure(e)) rethrow;
      final plans = _plans;
      if (plans == null) rethrow;
      return List<MealPlan>.of(plans);
    }
  }

  Future<void> generateShoppingList(MealPlan mealPlan) => apiClient.generateShoppingList(mealPlan);

  Future<MealPlan> fetchMealPlan(String id) async {
    try {
      final plan = await apiClient.getMealPlan(id);
      await _upsert(plan);
      return plan;
    } catch (e) {
      if (!isConnectivityFailure(e)) rethrow;
      await _ensureLoaded();
      for (final plan in _plans ?? const <MealPlan>[]) {
        if (plan.id.toString() == id) return plan;
      }
      rethrow;
    }
  }

  Future<MealPlan> addMealPlan(
    MealPlan mealPlan, {
    bool generateShoppingList = false,
  }) async {
    final saved = await apiClient.createMealPlan(
      mealPlan,
      generateShoppingList: generateShoppingList,
    );
    await _upsert(saved);
    return saved;
  }

  Future<MealPlan> updateMealPlan(MealPlan mealPlan) async {
    final saved = await apiClient.updateMealPlan(mealPlan);
    await _upsert(saved);
    return saved;
  }


  Future<DailyMealPlan> updateDailyMealPlan({
    required String mealPlanId,
    required String dailyMealPlanId,
    required DailyMealPlan dailyMealPlan,
  }) =>
      apiClient.updateDailyMealPlan(
        mealPlanId: mealPlanId,
        dailyMealPlanId: dailyMealPlanId,
        dailyMealPlan: dailyMealPlan,
      );

  Future<int> removeDailyMealPlan({
    required String mealPlanId,
    required String dailyMealPlanId,
  }) =>
      apiClient.deleteDailyMealPlan(
        mealPlanId: mealPlanId,
        dailyMealPlanId: dailyMealPlanId,
      );

  Future<int> removeMealPlan(int id) async {
    final status = await apiClient.deleteMealPlan(id.toString());
    await _ensureLoaded();
    final plans = _plans;
    if (plans != null) {
      _setPlans(plans.where((p) => p.id != id).toList());
    }
    return status;
  }
}
