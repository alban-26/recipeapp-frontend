import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../offline/ConnectionStatus.dart';
import '../MealPlanRepository.dart';
import '../domain/MealPlan.dart';
import 'MealPlanEvent.dart';
import 'MealPlanState.dart';

class MealPlanBloc extends Bloc<MealPlanEvent, MealPlanState> {
  final MealPlanRepository dataRepo;

  StreamSubscription<void>? _reconnectedSub;

  MealPlanBloc({required this.dataRepo, ConnectionStatus? connectionStatus}) : super(LoadingMealPlanState()) {
    // Verbindung wieder da: den (evtl. nur lokal gespeicherten) Stand auffrischen.
    _reconnectedSub = connectionStatus?.onReconnected.listen((_) {
      if (isClosed) return;
      if (state is LoadedMealPlanState) {
        add(PullToRefreshEvent());
      } else if (state is FailedToLoadMealPlanState) {
        add(LoadMealPlanEvent());
      }
    });

    on<LoadMealPlanEvent>((event, emit) async {
      // Gespeicherten Stand sofort zeigen, erst danach den Server fragen.
      List<MealPlan>? cached;
      try {
        cached = await dataRepo.cachedMealPlans();
      } catch (_) {}

      if (cached != null) {
        emit(LoadedMealPlanState(mealPlans: cached));
      } else {
        emit(LoadingMealPlanState());
      }

      try {
        final mealPlans = await dataRepo.fetchMealPlans();
        emit(LoadedMealPlanState(mealPlans: mealPlans));
      } catch (exception) {
        if (cached == null) {
          emit(FailedToLoadMealPlanState(error: exception));
        }
      }
    });
    on<PullToRefreshEvent>((event, emit) async {
      try {
        final mealPlans = await dataRepo.fetchMealPlans();
        emit(LoadedMealPlanState(mealPlans: mealPlans));
      } catch (exception) {
        emit(FailedToLoadMealPlanState(error: exception));
      }
    });
    on<MealPlanAdded>((event, emit) async {
      try {
        await dataRepo.addMealPlan(event.mealPlan);
        final mealPlans = await dataRepo.fetchMealPlans();
        emit(LoadedMealPlanState(mealPlans: mealPlans));
      } catch (exception) {
        emit(FailedToLoadMealPlanState(error: exception));
      }
    });
    on<MealPlanDeleted>((event, emit) async {
      try {
        await dataRepo.removeMealPlan(event.mealPlan.id);
        final mealPlans = await dataRepo.fetchMealPlans();
        emit(LoadedMealPlanState(mealPlans: mealPlans));
      } catch (exception) {
        emit(FailedToLoadMealPlanState(error: exception));
      }
    });
  }

  @override
  Future<void> close() {
    _reconnectedSub?.cancel();
    return super.close();
  }
}
