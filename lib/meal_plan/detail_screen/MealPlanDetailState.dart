import '../domain/MealPlan.dart';

abstract class MealPlansDetailState {}

class LoadedMealPlanDetailState extends MealPlansDetailState {
  final MealPlan mealPlan;

  /// Einmalige Rueckmeldung fuer den Nutzer (z.B. "Einkaufsliste wurde
  /// erstellt"), null wenn es nichts zu melden gibt.
  final String? notice;

  LoadedMealPlanDetailState({required this.mealPlan, this.notice});
}


class LoadingMealPlansDetailState extends MealPlansDetailState {}