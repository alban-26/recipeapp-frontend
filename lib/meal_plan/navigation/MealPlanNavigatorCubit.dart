import 'package:bloc/bloc.dart';

import '../MealPlanRepository.dart';
import '../domain/MealPlan.dart';

abstract class MealPlanNavigatorState {}

class MealPlanCubitState extends MealPlanNavigatorState {}

class MealPlanNavigatorInitial extends MealPlanNavigatorState {}

class MealPlanDetailState extends MealPlanNavigatorState {
  final MealPlan mealPlan;

  MealPlanDetailState({required this.mealPlan});

  MealPlanDetailState copyWith({
    required MealPlan mealPlan,
  }) {
    return MealPlanDetailState(
      mealPlan: mealPlan,
    );
  }
}

class MealPlanCreateState extends MealPlanNavigatorState {
  final MealPlan mealPlan;

  MealPlanCreateState({required this.mealPlan});
}

class MealPlanUpdateState extends MealPlanNavigatorState {
  final MealPlan mealPlan;

  MealPlanUpdateState(this.mealPlan);
}




class MealPlanNavigatorCubit extends Cubit<MealPlanNavigatorState> {
  final MealPlanRepository repository;

  MealPlanNavigatorCubit({required this.repository})
      : super(MealPlanCubitState());

  void showMealPlanDetail(MealPlan mealPlan) =>
      emit(MealPlanDetailState(mealPlan: mealPlan));

  void showMealPlanUpdate(MealPlan plan) {
    emit(MealPlanUpdateState(plan));
  }


  void showMealPlans() => emit(MealPlanCubitState());

  void showCreateMealPlan(MealPlan mealPlan) {
    emit(MealPlanCreateState(
      mealPlan: MealPlan(
          id: 0,
          startDate: mealPlan.startDate,
          endDate: mealPlan.endDate,
          dailyMealPlans: []),
    ));
  }

  void updateMealPlan(MealPlan mealPlan) {
    if (state is MealPlanCreateState) {
      emit(MealPlanCreateState(mealPlan: mealPlan));
    } else if (state is MealPlanDetailState) {
      emit(MealPlanDetailState(mealPlan: mealPlan));
    }
  }

  void cancelCreateMealPlan() {
    emit(MealPlanCubitState());
  }
}
