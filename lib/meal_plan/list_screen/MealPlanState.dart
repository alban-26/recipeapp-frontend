import '../domain/MealPlan.dart';

abstract class MealPlanState {}

class MealPlanInitialState extends MealPlanState {}

class LoadingMealPlanState extends MealPlanState {}

class LoadedMealPlanState extends MealPlanState {
  List<MealPlan> mealPlans;

  LoadedMealPlanState({required this.mealPlans});
}

class CreateMealPlanState extends MealPlanState {}

class FailedToLoadMealPlanState extends MealPlanState {
  // Object statt Error: Netzwerkfehler (DioException) sind Exceptions und
  // wurden vorher gar nicht abgefangen - die Seite blieb beim Ladekreis haengen.
  Object error;

  FailedToLoadMealPlanState({required this.error});
}
