
import 'package:recipeapp_frontend/meal_plan/domain/DailyMealPlan.dart';


abstract class MealPlanDetailEvent {}

class LoadMealPlanDetailEvent extends MealPlanDetailEvent {}

class RefreshMealPlanDetailEvent extends MealPlanDetailEvent {}


class DeleteMealPlanItemEvent extends MealPlanDetailEvent {
  final DailyMealPlan item;
  final int mealPlanId;
  DeleteMealPlanItemEvent(this.item, this.mealPlanId);
}


class GenerateShoppingListEvent extends MealPlanDetailEvent {}
