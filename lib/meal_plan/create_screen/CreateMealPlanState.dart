import '../domain/MealPlan.dart';
import '../domain/RecipeRef.dart';

abstract class CreateMealPlansState {}

class CreateMealPlanInitial extends CreateMealPlansState {}

class CreateMealPlanLoading extends CreateMealPlansState {}

class CreateMealPlanLoaded extends CreateMealPlansState {
  final MealPlan mealPlan;
  final List<RecipeRef> availableRecipes;

  CreateMealPlanLoaded({
    required this.mealPlan,
    required this.availableRecipes,
  });

  CreateMealPlanLoaded copyWith({
    MealPlan? mealPlan,
    List<RecipeRef>? availableRecipes,
  }) {
    return CreateMealPlanLoaded(
      mealPlan: mealPlan ?? this.mealPlan,
      availableRecipes: availableRecipes ?? this.availableRecipes,
    );
  }
}

class CreateMealPlanSaving extends CreateMealPlansState {}

class CreateMealPlanSaved extends CreateMealPlansState {
  final MealPlan saved;
  CreateMealPlanSaved(this.saved);
}
