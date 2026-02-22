import '../StorageRepository.dart';
import '../api/BaseApiClient.dart';
import 'domain/DailyMealPlan.dart';
import 'domain/MealPlan.dart';
import 'domain/RecipeRef.dart';

class MealPlanApiClient extends BaseApiClient {
  final StorageRepository storageRepository;

  MealPlanApiClient({
    required super.dio,
    required super.secureStorage,
    required super.baseUrl,
    required this.storageRepository,
  });

  // ---------------------------
  // GET /mealplans/recipes
  // ---------------------------
  Future<List<RecipeRef>> getRecipes() async {
    final response = await dio.get('$baseUrl/mealplans/recipes');
    return (response.data as List)
        .map((e) => RecipeRef.fromJson(e))
        .toList();
  }

  // ---------------------------
  // GET /mealplans
  // ---------------------------
  Future<List<MealPlan>> getMealPlans() async {
    final response = await dio.get('$baseUrl/mealplans');
    if (response.statusCode == 204 || response.data == null || response.data == "") {
      return [];
    }
    return (response.data as List)
        .map((e) => MealPlan.fromJson(e))
        .toList();
  }

  // ---------------------------
  // GET /mealplans/{id}
  // ---------------------------
  Future<MealPlan> getMealPlan(String id) async {
    final response = await dio.get('$baseUrl/mealplans/$id');
    return MealPlan.fromJson(response.data);
  }

  // ---------------------------
  // POST /mealplans?generateShoppingList=true/false
  // ---------------------------
  Future<MealPlan> createMealPlan(
      MealPlan mealPlan, {
        bool generateShoppingList = false,
      }) async {
    final response = await dio.post(
      '$baseUrl/mealplans',
      queryParameters: {
        'generateShoppingList': generateShoppingList,
      },
      data: mealPlan.toJson(),
    );

    return MealPlan.fromJson(response.data);
  }

  // ---------------------------
  // PUT /mealplans/{id}
  // ---------------------------
  Future<MealPlan> updateMealPlan(
      MealPlan mealPlan,
      ) async {
    final response = await dio.put(
      '$baseUrl/mealplans/${mealPlan.id}',
      data: mealPlan.toJson(),
    );

    return MealPlan.fromJson(response.data);
  }

  // ---------------------------
  // PUT /mealplans/{mealPlanId}/dailyMealPlans/{dailyMealPlanId}
  // ---------------------------
  Future<DailyMealPlan> updateDailyMealPlan({
    required String mealPlanId,
    required String dailyMealPlanId,
    required DailyMealPlan dailyMealPlan,
  }) async {
    final response = await dio.put(
      '$baseUrl/mealplans/$mealPlanId/dailyMealPlans/$dailyMealPlanId',
      data: dailyMealPlan.toJson(),
    );

    return DailyMealPlan.fromJson(response.data);
  }

  // ---------------------------
  // DELETE /mealplans/{mealPlanId}/dailyMealPlans/{dailyMealPlanId}
  // ---------------------------
  Future<int> deleteDailyMealPlan({
    required String mealPlanId,
    required String dailyMealPlanId,
  }) async {
    final response = await dio.delete(
      '$baseUrl/mealplans/$mealPlanId/dailyMealPlans/$dailyMealPlanId',
    );

    return response.statusCode ?? 204;
  }

  Future<int> deleteMealPlan(String id) async {
    final response = await dio.delete('$baseUrl/mealplans/$id');

    // The API returns 204 if successful — return it for consistency
    return response.statusCode ?? 204;
  }

  // ---------------------------
// POST /mealplans/generateShoppingList
// ---------------------------
  Future<void> generateShoppingList(MealPlan mealPlan) async {
    await dio.post(
      '$baseUrl/mealplans/generateShoppingList',
      data: mealPlan.toJson(),
    );
  }


}
