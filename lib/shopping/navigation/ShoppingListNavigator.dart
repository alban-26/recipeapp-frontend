import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../ShoppingListRepository.dart';
import '../detail_screen/ShoppingListDetailScreen.dart';
import '../list_screen/ShoppingListScreen.dart';
import 'ShoppingListNavigatorCubit.dart';



class ShoppingNavigator extends StatelessWidget {
  const ShoppingNavigator({
    super.key,
    required this.navigatorKey,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ShoppingNavigatorCubit(
        repository: context.read<ShoppingListRepository>(),
      ),
      child: BlocBuilder<ShoppingNavigatorCubit, ShoppingNavigatorState>(
        builder: (context, state) {
          return Navigator(
            key: navigatorKey,
            pages: [
              if (state is ShoppingListCubitState)
                const MaterialPage(child: ShoppingListScreen()),

              if (state is ShoppingListDetailState)
                MaterialPage(
                  key: ValueKey('detail_${state.shoppingList.id}'),
                  child: ShoppingListDetailScreen(
                    shoppingList: state.shoppingList,
                  ),
                ),

              // Optional: Create Screen, falls vorhanden
              if (state is ShoppingListCreateState)
                MaterialPage(
                  key: const ValueKey('create_shopping'),
                  child: ShoppingListDetailScreen(
                    shoppingList: state.shoppingList,
                  ),
                ),
            ],
            onPopPage: (route, result) {
              if (!route.didPop(result)) return false;

              final cubit = context.read<ShoppingNavigatorCubit>();
              final currentState = cubit.state;

              if (currentState is ShoppingListDetailState ||
                  currentState is ShoppingListCreateState) {
                cubit.showShoppingLists();
              } else {
                cubit.showShoppingLists();
              }

              return true;
            },
          );
        },
      ),
    );
  }
}
