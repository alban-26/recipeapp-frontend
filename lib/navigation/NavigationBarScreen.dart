import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recipeapp_frontend/profile/profile_view.dart';

import '../meal_plan/navigation/MealPlanNavigator.dart';
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

  int get index => _bottomNavCubit.state;

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

            body: IndexedStack(
              index: index,
              children: [
                RecipeNavigator(navigatorKey: recipeNavKey),
                ShoppingNavigator(navigatorKey: shoppingNavKey),
                MealPlanNavigator(navigatorKey: mealPlanNavKey),
                const ProfileView(),
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
