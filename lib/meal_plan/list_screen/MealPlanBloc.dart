import 'package:flutter_bloc/flutter_bloc.dart';

import '../MealPlanRepository.dart';
import 'MealPlanEvent.dart';
import 'MealPlanState.dart';

class MealPlanBloc extends Bloc<MealPlanEvent, MealPlanState> {
  final MealPlanRepository dataRepo;

  MealPlanBloc({required this.dataRepo}) : super(LoadingMealPlanState()) {
    on<LoadMealPlanEvent>((event, emit) async {
      emit(LoadingMealPlanState());
      try {
        final mealPlans = await dataRepo.fetchMealPlans();
        emit(LoadedMealPlanState(mealPlans: mealPlans));
      } on Error catch (exception) {
        emit(FailedToLoadMealPlanState(error: exception));
      }
    });
    on<PullToRefreshEvent>((event, emit) async {
      try {
        final mealPlans = await dataRepo.fetchMealPlans();
        emit(LoadedMealPlanState(mealPlans: mealPlans));
      } on Error catch (exception) {
        emit(FailedToLoadMealPlanState(error: exception));
      }
    });
    on<MealPlanAdded>((event, emit) async {
      try {
        await dataRepo.addMealPlan(event.mealPlan);
        final mealPlans = await dataRepo.fetchMealPlans();
        emit(LoadedMealPlanState(mealPlans: mealPlans));
      } on Error catch (exception) {
        emit(FailedToLoadMealPlanState(error: exception));
      }
    });
    on<MealPlanDeleted>((event, emit) async {
      try {
        await dataRepo.removeMealPlan(event.mealPlan.id);
        final mealPlans = await dataRepo.fetchMealPlans();
        emit(LoadedMealPlanState(mealPlans: mealPlans));
      } on Error catch (exception) {
        emit(FailedToLoadMealPlanState(error: exception));
      }
    });
  }
}
