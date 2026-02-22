import '../domain/MealPlan.dart';

abstract class MealPlansDetailState {}

class LoadedMealPlanDetailState extends MealPlansDetailState {
  final MealPlan mealPlan;

  LoadedMealPlanDetailState({required this.mealPlan});
}


class LoadingMealPlansDetailState extends MealPlansDetailState {}