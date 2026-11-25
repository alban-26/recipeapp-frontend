import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/recipe/create_screen/CreateRecipeScreen.dart';

import '../RecipeRepository.dart';
import '../detail_screen/RecipeScreen.dart';
import '../import/SharedRecipeLinks.dart';
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
      child: _SharedLinkListener(
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
                  key: state.importRequest == null ? null : ObjectKey(state.importRequest),
                  child: CreateRecipeScreen(
                    recipe: state.recipe,
                    importText: state.importText,
                  ),
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
      ),
    );
  }
}

/// Oeffnet fuer einen geteilten Link das Formular "Rezept erstellen" mit Import.
class _SharedLinkListener extends StatefulWidget {
  const _SharedLinkListener({required this.child});

  final Widget child;

  @override
  State<_SharedLinkListener> createState() => _SharedLinkListenerState();
}

class _SharedLinkListenerState extends State<_SharedLinkListener> {
  late final SharedRecipeLinks _links = context.read<SharedRecipeLinks>();

  @override
  void initState() {
    super.initState();
    _links.pending.addListener(_handle);
    // Schon vor der Anmeldung geteilt: jetzt abholen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handle());
  }

  @override
  void dispose() {
    _links.pending.removeListener(_handle);
    super.dispose();
  }

  void _handle() {
    if (!mounted || _links.pending.value == null) return;
    final text = _links.take();
    if (text != null) context.read<RecipeNavigatorCubit>().showImportRecipe(text);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
