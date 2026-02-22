import 'package:flutter_bloc/flutter_bloc.dart';

import '../MealPlanRepository.dart';
import '../domain/DailyMealPlan.dart';
import '../domain/Meal.dart';
import '../domain/MealPlan.dart';
import 'CreateMealPlanEvent.dart';
import 'CreateMealPlanState.dart';

class CreateMealPlanBloc
    extends Bloc<CreateMealPlanEvent, CreateMealPlansState> {

  final MealPlanRepository repo;
  MealPlan _mealPlan;

  final bool isEditing;

  CreateMealPlanBloc({
    required MealPlan initialMealPlan,
    required this.repo,
    this.isEditing = false
  }) : _mealPlan = initialMealPlan,
        super(CreateMealPlanInitial()) {
    on<LoadCreateMealPlanData>(_onLoad);

    on<AddDailyMealPlan>(_onAddDay);
    on<RemoveDailyMealPlan>(_onRemoveDay);
    on<AddMealToDay>(_onAddMeal);
    on<RemoveMealFromDay>(_onRemoveMeal);
    on<SaveMealPlan>(_onSave);
    on<GenerateDailyMealPlans>(_onGenerateDailyMealPlans);


    add(LoadCreateMealPlanData());
  }

  Future<void> _onLoad(
      LoadCreateMealPlanData event,
      Emitter<CreateMealPlansState> emit,
      ) async {
    emit(CreateMealPlanLoading());

    final recipes = await repo.getAllRecipes();

    emit(CreateMealPlanLoaded(
      mealPlan: _mealPlan,
      availableRecipes: recipes,
    ));

    if (!isEditing) {
      add(GenerateDailyMealPlans());
    }
  }




  void _onAddDay(AddDailyMealPlan event, Emitter emit) {
    if (state is! CreateMealPlanLoaded) return;

    final current = state as CreateMealPlanLoaded;

    final day = DailyMealPlan(
      id: DateTime.now().millisecondsSinceEpoch,
      date: event.date,
      meals: {},
    );

    final updatedPlan = _mealPlan.copyWith(
      dailyMealPlans: [..._mealPlan.dailyMealPlans, day],
    );

    _mealPlan = updatedPlan;

    emit(current.copyWith(mealPlan: updatedPlan));
  }


  Future<void> _onGenerateDailyMealPlans(
      GenerateDailyMealPlans event,
      Emitter<CreateMealPlansState> emit,
      ) async {
    if (state is! CreateMealPlanLoaded) return;

    final current = state as CreateMealPlanLoaded;
    final plan = _mealPlan;

    final days = <DailyMealPlan>[];
    DateTime date = plan.startDate;

    while (!date.isAfter(plan.endDate)) {
      days.add(
        DailyMealPlan(
          id: date.millisecondsSinceEpoch,
          date: date,
          meals: {},
        ),
      );

      date = date.add(const Duration(days: 1));
    }

    final updatedPlan = plan.copyWith(dailyMealPlans: days);
    _mealPlan = updatedPlan;

    emit(
      current.copyWith(
        mealPlan: updatedPlan,
      ),
    );
  }




  void _onRemoveDay(RemoveDailyMealPlan event, Emitter emit) {
    if (state is! CreateMealPlanLoaded) return;

    final current = state as CreateMealPlanLoaded;

    final updatedDays = _mealPlan.dailyMealPlans
        .where((d) => d.id != event.dailyId)
        .toList();

    final updatedPlan = _mealPlan.copyWith(
      dailyMealPlans: updatedDays,
    );

    _mealPlan = updatedPlan;

    emit(current.copyWith(mealPlan: updatedPlan));
  }

  void _onAddMeal(AddMealToDay event, Emitter emit) {
    if (state is! CreateMealPlanLoaded) return;

    final current = state as CreateMealPlanLoaded;

    final days = [..._mealPlan.dailyMealPlans];
    final index = days.indexWhere((d) => d.id == event.dailyId);

    final day = days[index];
    final meals = Map.of(day.meals);

    meals[event.mealtime] = [
      ...?meals[event.mealtime],
      Meal(recipe: event.recipe, servings: event.servings)
    ];

    final updatedDay = day.copyWith(meals: meals);
    days[index] = updatedDay;

    final updatedPlan = _mealPlan.copyWith(dailyMealPlans: days);
    _mealPlan = updatedPlan;

    emit(current.copyWith(mealPlan: updatedPlan));
  }

  void _onRemoveMeal(RemoveMealFromDay event, Emitter emit) {
    if (state is! CreateMealPlanLoaded) return;

    final current = state as CreateMealPlanLoaded;

    final days = [..._mealPlan.dailyMealPlans];
    final index = days.indexWhere((d) => d.id == event.dailyId);

    final day = days[index];
    final meals = Map.of(day.meals);

    meals[event.mealtime] =
        meals[event.mealtime]!.where((m) => m != event.meal).toList();

    final updatedDay = day.copyWith(meals: meals);
    days[index] = updatedDay;

    final updatedPlan = _mealPlan.copyWith(dailyMealPlans: days);
    _mealPlan = updatedPlan;

    emit(current.copyWith(mealPlan: updatedPlan));
  }

  Future<void> _onSave(SaveMealPlan event, Emitter emit) async {
    if (state is! CreateMealPlanLoaded) return;
    emit(CreateMealPlanSaving());

    final saved = _mealPlan.id == 0
        ? await repo.addMealPlan(_mealPlan)
        : await repo.updateMealPlan(_mealPlan);

    emit(CreateMealPlanSaved(saved));
  }

}
