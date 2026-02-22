import '../domain/Meal.dart';
import '../domain/Mealtime.dart';
import '../domain/RecipeRef.dart';

abstract class CreateMealPlanEvent {}

class LoadCreateMealPlanData extends CreateMealPlanEvent {}

class AddDailyMealPlan extends CreateMealPlanEvent {
  final DateTime date;
  AddDailyMealPlan(this.date);
}

class RemoveDailyMealPlan extends CreateMealPlanEvent {
  final int dailyId;
  RemoveDailyMealPlan(this.dailyId);
}

class GenerateDailyMealPlans extends CreateMealPlanEvent {}

class LoadExistingMealPlan extends CreateMealPlanEvent {}


class AddMealToDay extends CreateMealPlanEvent {
  final int dailyId;
  final Mealtime mealtime;
  final RecipeRef recipe;
  final int servings;

  AddMealToDay({
    required this.dailyId,
    required this.mealtime,
    required this.recipe,
    required this.servings,
  });
}

class RemoveMealFromDay extends CreateMealPlanEvent {
  final int dailyId;
  final Mealtime mealtime;
  final Meal meal;

  RemoveMealFromDay({
    required this.dailyId,
    required this.mealtime,
    required this.meal,
  });
}

class SaveMealPlan extends CreateMealPlanEvent {}
