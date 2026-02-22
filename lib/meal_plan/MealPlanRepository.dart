import 'MealPlanApiClient.dart';
import 'domain/DailyMealPlan.dart';
import 'domain/MealPlan.dart';
import 'domain/RecipeRef.dart';

class MealPlanRepository {
  final MealPlanApiClient apiClient;

  MealPlanRepository({required this.apiClient});

  Future<List<RecipeRef>> getAllRecipes() async {
    return apiClient.getRecipes();
  }

  Future<List<MealPlan>> fetchMealPlans() => apiClient.getMealPlans();

  Future<void> generateShoppingList(MealPlan mealPlan) => apiClient.generateShoppingList(mealPlan);

  Future<MealPlan> fetchMealPlan(String id) => apiClient.getMealPlan(id);

  Future<MealPlan> addMealPlan(
    MealPlan mealPlan, {
    bool generateShoppingList = false,
  }) =>
      apiClient.createMealPlan(
        mealPlan,
        generateShoppingList: generateShoppingList,
      );

  Future<MealPlan> updateMealPlan(MealPlan mealPlan) =>
      apiClient.updateMealPlan(mealPlan);


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

  Future<int> removeMealPlan(int id) => apiClient.deleteMealPlan(id.toString());
}
