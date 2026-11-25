import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/profile/profile_view.dart';

import '../meal_plan/navigation/MealPlanNavigator.dart';
import '../offline/OfflineBanner.dart';
import '../offline/SyncQueue.dart';
import '../recipe/import/SharedRecipeLinks.dart';
import '../recipe/navigation/RecipeNavigator.dart';
import '../shopping/navigation/ShoppingListNavigator.dart';
import 'NavigationBarCubit.dart';

class BottomNavBarView extends StatefulWidget {
  const BottomNavBarView({super.key});

  @override
  State<BottomNavBarView> createState() => BottomNavBarViewState();
}

class BottomNavBarViewState extends State<BottomNavBarView> {
  final _bottomNavCubit = BottomNavBarCubit();

  final recipeNavKey = GlobalKey<NavigatorState>();
  final shoppingNavKey = GlobalKey<NavigatorState>();
  final mealPlanNavKey = GlobalKey<NavigatorState>();

  StreamSubscription<SyncFailure>? _syncFailureSub;
  late final SharedRecipeLinks _sharedLinks = context.read<SharedRecipeLinks>();

  int get index => _bottomNavCubit.state;

  @override
  void initState() {
    super.initState();
    // Eine offline gemachte Aenderung, die der Server endgueltig ablehnt
    // (z.B. weil die Liste auf einem anderen Geraet geloescht wurde), soll
    // nicht stillschweigend verschwinden.
    _syncFailureSub = context.read<SyncQueue>().failures.listen((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Eine Änderung konnte nicht gespeichert werden und wurde verworfen.'),
        ),
      );
    });

    // Geteilter Link: zum Rezept-Bereich wechseln, der oeffnet den Import.
    _sharedLinks.pending.addListener(_showRecipesForSharedLink);
    _showRecipesForSharedLink();
  }

  void _showRecipesForSharedLink() {
    if (_sharedLinks.pending.value != null) _bottomNavCubit.selectTab(0);
  }

  @override
  void dispose() {
    _sharedLinks.pending.removeListener(_showRecipesForSharedLink);
    _syncFailureSub?.cancel();
    _bottomNavCubit.close();
    super.dispose();
  }

  void selectTab(int newIndex) {
    _bottomNavCubit.selectTab(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bottomNavCubit,
      child: BlocBuilder<BottomNavBarCubit, int>(
        builder: (context, index) {
          return Scaffold(

            body: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: index,
                    children: [
                      RecipeNavigator(navigatorKey: recipeNavKey),
                      ShoppingNavigator(navigatorKey: shoppingNavKey),
                      MealPlanNavigator(navigatorKey: mealPlanNavKey),
                      const ProfileView(),
                    ],
                  ),
                ),
                // Erscheint nur ohne Verbindung bzw. bei wartenden Aenderungen.
                const OfflineBanner(),
              ],
            ),

            bottomNavigationBar: NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (newIndex) {
                _bottomNavCubit.selectTab(newIndex);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.restaurant_menu_outlined),
                  selectedIcon: Icon(Icons.restaurant_menu),
                  label: 'Rezepte',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_cart_outlined),
                  selectedIcon: Icon(Icons.shopping_cart),
                  label: 'Einkauf',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Plan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profil',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
