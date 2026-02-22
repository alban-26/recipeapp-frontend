import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../MealPlanRepository.dart';
import '../create_screen/CreateMealPlanScreen.dart';
import '../detail_screen/MealPlanDetailScreen.dart';
import '../list_screen/MealPlanScreen.dart';
import 'MealPlanNavigatorCubit.dart';

class MealPlanNavigator extends StatelessWidget {
  const MealPlanNavigator({
    super.key,
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MealPlanNavigatorCubit(
        repository: context.read<MealPlanRepository>(),
      ),
      child: BlocBuilder<MealPlanNavigatorCubit, MealPlanNavigatorState>(
        builder: (context, state) {
          return Navigator(
            key: navigatorKey,
            pages: [
              if (state is MealPlanCubitState)
                const MaterialPage(child: MealPlanScreen()),

              if (state is MealPlanDetailState)
                MaterialPage(
                  key: ValueKey('detail_${state.mealPlan.id}'),
                  child: MealPlanDetailScreen(mealPlan: state.mealPlan),
                ),

              if (state is MealPlanCreateState)
                MaterialPage(
                  key: const ValueKey('create_mealplan'),
                  child: CreateMealPlanScreen(mealPlan: state.mealPlan),
                ),

              if (state is MealPlanUpdateState)
                MaterialPage(
                  key: const ValueKey('update_mealplan'),
                  child: CreateMealPlanScreen(
                    mealPlan: state.mealPlan,
                    isEditing: true,
                  ),
                ),
            ],
            onPopPage: (route, result) {
              if (!route.didPop(result)) return false;

              final cubit = context.read<MealPlanNavigatorCubit>();
              final currentState = cubit.state;

              if (currentState is MealPlanDetailState ||
                  currentState is MealPlanCreateState ||
                  currentState is MealPlanUpdateState) {
                cubit.showMealPlans();
              } else {
                cubit.showMealPlans();
              }

              return true;
            },
          );
        },
      ),
    );
  }
}
