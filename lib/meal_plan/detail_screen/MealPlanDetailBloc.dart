import 'package:flutter_bloc/flutter_bloc.dart';
import '../MealPlanRepository.dart';
import '../domain/MealPlan.dart';
import 'MealPlanDetailEvent.dart';
import 'MealPlanDetailState.dart';

class MealPlanDetailBloc
    extends Bloc<MealPlanDetailEvent, MealPlansDetailState> {
  final MealPlanRepository dataRepo;

  MealPlanDetailBloc({required this.dataRepo, required MealPlan initialList})
      : super(LoadedMealPlanDetailState(mealPlan: initialList)) {
    on<LoadMealPlanDetailEvent>((event, emit) {
      // Already have the data, just emit
      emit(state);
    });

    on<RefreshMealPlanDetailEvent>((event, emit) {
      emit(state);
    });

    on<GenerateShoppingListEvent>((event, emit) async {
      final currentState = state as LoadedMealPlanDetailState;
      await dataRepo.generateShoppingList(currentState.mealPlan);
      emit(state);
    });

    on<DeleteMealPlanItemEvent>((event, emit) {
      final currentState = state as LoadedMealPlanDetailState;
      final updatedItems = currentState.mealPlan.dailyMealPlans
          .where((i) => i.id != event.item.id)
          .toList();
      dataRepo.removeDailyMealPlan(mealPlanId: '', dailyMealPlanId: '');
      emit(LoadedMealPlanDetailState(
        mealPlan: currentState.mealPlan.copyWith(
          dailyMealPlans: updatedItems,
        ),
      ));
    });
  }
}
