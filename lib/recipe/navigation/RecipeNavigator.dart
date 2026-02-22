import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/recipe/create_screen/CreateRecipeScreen.dart';

import '../RecipeRepository.dart';
import '../detail_screen/RecipeScreen.dart';
import '../list_screen/RecipesScreen.dart';
import 'RecipeNavigatorCubit.dart';

class RecipeNavigator extends StatelessWidget {
  const RecipeNavigator({
    super.key,
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          RecipeNavigatorCubit(dataRepo: context.read<RecipeRepository>()),
      child: BlocBuilder<RecipeNavigatorCubit, RecipeNavigatorState>(
        builder: (context, state) {
          return Navigator(
            key: navigatorKey,
            pages: [
              if (state is RecipeListState)
                const MaterialPage(child: RecipesScreen()),

              if (state is RecipeDetailState)
                MaterialPage(child: RecipeScreen(recipe: state.recipe)),

              if (state is RecipeCreateState)
                MaterialPage(
                  child: CreateRecipeScreen(recipe: state.recipe),
                ),
            ],
            onPopPage: (route, result) {
              if (!route.didPop(result)) return false;

              final cubit = context.read<RecipeNavigatorCubit>();
              final currentState = cubit.state;

              if (currentState is RecipeCreateState) {
                if (currentState.recipe.id != 0) {
                  cubit.showRecipeDetail(currentState.recipe);
                } else {
                  cubit.showRecipes();
                }
              } else if (currentState is RecipeDetailState) {
                cubit.showRecipes();
              } else {
                cubit.showRecipes();
              }

              return true;
            },
          );
        },
      ),
    );
  }
}
