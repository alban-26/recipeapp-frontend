import '../domain/MealPlan.dart';
import '../domain/RecipeRef.dart';

abstract class CreateMealPlansState {}

class CreateMealPlanInitial extends CreateMealPlansState {}

class CreateMealPlanLoading extends CreateMealPlansState {}

class CreateMealPlanLoaded extends CreateMealPlansState {
  final MealPlan mealPlan;
  final List<RecipeRef> availableRecipes;

  /// Gesetzt, wenn das Speichern gerade fehlgeschlagen ist (einmalig).
  final Object? saveError;

  CreateMealPlanLoaded({
    required this.mealPlan,
    required this.availableRecipes,
    this.saveError,
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
