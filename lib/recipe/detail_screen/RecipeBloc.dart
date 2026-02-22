import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/Recipe.dart';
import '../domain/RecipeIngredient.dart';
import '../navigation/RecipeNavigatorCubit.dart';
import 'RecipeEvent.dart';

class RecipeBloc extends Bloc<RecipeEvent, RecipeDetailState> {
  RecipeBloc({required Recipe recipe})
      : super(RecipeDetailState(recipe: recipe)) {
    on<IncrementPortions>((event, emit) async {
      final portionsOld = state.recipe.portions;
      final portionsNew = portionsOld + 1;

      List<RecipeIngredient> recipeIngredients = state.recipe.recipeIngredients
          .map((e) => e.copyWith(
              quantity: getNewAmount(e.quantity, portionsOld, portionsNew)))
          .toList();
      Recipe recipeNew = state.recipe.copyWith(
          portions: portionsNew, recipeIngredients: recipeIngredients);
      emit(state.copyWith(recipe: recipeNew));
    });
    on<DecrementPortions>((event, emit) async {
      final portionsOld = state.recipe.portions;
      final portionsNew = portionsOld - 1;

      List<RecipeIngredient> recipeIngredients = state.recipe.recipeIngredients
          .map((e) => e.copyWith(
              quantity: getNewAmount(e.quantity, portionsOld, portionsNew)))
          .toList();
      Recipe recipeNew = state.recipe.copyWith(
          portions: portionsNew, recipeIngredients: recipeIngredients);
      emit(state.copyWith(recipe: recipeNew));
    });
  }

  double getNewAmount(double amountOld, int portionsOld, int portionsNew) {
    final double quotient = amountOld / portionsOld;
    final result = quotient * portionsNew;
    return result;
  }
}
