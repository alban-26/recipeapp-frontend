import '../domain/MealPlan.dart';

abstract class MealPlanEvent {}

class LoadMealPlanEvent extends MealPlanEvent {}

class PullToRefreshEvent extends MealPlanEvent {}

class MealPlanAdded extends MealPlanEvent {
  final MealPlan mealPlan;
  MealPlanAdded(this.mealPlan);
}

class MealPlanDeleted extends MealPlanEvent {
  final MealPlan mealPlan;
  MealPlanDeleted(this.mealPlan);
}
