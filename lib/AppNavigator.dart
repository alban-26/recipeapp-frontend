// Updated AppNavigator with registration flow

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/recipe/navigation/RecipeNavigatorCubit.dart';
import 'package:recipeapp_frontend/session/SessionCubit.dart';
import 'package:recipeapp_frontend/session/SessionState.dart';
import 'package:recipeapp_frontend/shopping/navigation/ShoppingListNavigatorCubit.dart';

import 'LoadingScreen.dart';
import 'auth/navigation/AuthCubit.dart';
import 'auth/navigation/AuthNavigator.dart';
import 'meal_plan/navigation/MealPlanNavigatorCubit.dart';
import 'navigation/NavigationBarScreen.dart';


final GlobalKey<BottomNavBarViewState> bottomNavBarViewKey = GlobalKey();

class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      builder: (context, state) {
        return WillPopScope(
          onWillPop: () async {
            if (state is Authenticated) {
              final bottomNavState = bottomNavBarViewKey.currentState;
              if (bottomNavState == null) return true;

              final currentIndex = bottomNavState.index;

              if (currentIndex == 0) {
                final recipeCubit = bottomNavState.recipeNavKey.currentContext
                    ?.read<RecipeNavigatorCubit>();

                if (recipeCubit != null &&
                    recipeCubit.state is! RecipeListState) {
                  recipeCubit.showRecipes();
                  return false;
                }
              }

              if (currentIndex == 1) {
                final shoppingCubit = bottomNavState.shoppingNavKey.currentContext
                    ?.read<ShoppingNavigatorCubit>();

                if (shoppingCubit != null &&
                    shoppingCubit.state is! ShoppingListCubitState) {
                  shoppingCubit.showShoppingLists();
                  return false;
                }
              }

              if (currentIndex == 2) {
                final mealCubit = bottomNavState.mealPlanNavKey.currentContext
                    ?.read<MealPlanNavigatorCubit>();

                if (mealCubit != null &&
                    mealCubit.state is! MealPlanCubitState) {
                  mealCubit.showMealPlans();
                  return false;
                }
              }

              if (currentIndex != 0) {
                bottomNavState.selectTab(0);
                return false;
              }
            }

            return true;
          },
          child: Navigator(
            pages: [
              if (state is UnknownSessionState)
                const MaterialPage(child: LoadingScreen()),

              if (state is Unauthenticated)
                MaterialPage(
                  child: BlocProvider(
                    create: (context) => AuthCubit(
                      sessionCubit: context.read<SessionCubit>(),
                    ),
                    child: const AuthNavigator(),
                  ),
                ),

              if (state is Authenticated)
                MaterialPage(
                  child: BottomNavBarView(key: bottomNavBarViewKey),
                ),
            ],
            onPopPage: (route, result) => route.didPop(result),
          ),
        );
      },
    );
  }
}
