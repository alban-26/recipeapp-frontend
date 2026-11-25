import 'package:flutter_bloc/flutter_bloc.dart';
import '../../common/error_messages.dart';
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
      // Die Einkaufsliste entsteht auf dem Server - erst melden, wenn es
      // wirklich geklappt hat (vorher kam die Erfolgsmeldung auch offline).
      try {
        await dataRepo.generateShoppingList(currentState.mealPlan);
        emit(LoadedMealPlanDetailState(
          mealPlan: currentState.mealPlan,
          notice: 'Einkaufsliste wurde erstellt',
        ));
      } catch (e) {
        emit(LoadedMealPlanDetailState(
          mealPlan: currentState.mealPlan,
          notice: 'Einkaufsliste konnte nicht erstellt werden. ${userMessage(e)}',
        ));
      }
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
