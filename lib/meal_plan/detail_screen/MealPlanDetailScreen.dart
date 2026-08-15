import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/CommonUtils.dart';
import '../../widgets/CommonAppBar.dart';
import '../MealPlanRepository.dart';
import '../domain/DailyMealPlan.dart';
import '../domain/MealPlan.dart';
import '../navigation/MealPlanNavigatorCubit.dart';
import 'MealPlanDetailBloc.dart';
import 'MealPlanDetailEvent.dart';
import 'MealPlanDetailState.dart';

class MealPlanDetailScreen extends StatelessWidget {
  final MealPlan mealPlan;

  const MealPlanDetailScreen({super.key, required this.mealPlan});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MealPlanDetailBloc(
        initialList: mealPlan,
        dataRepo: context.read<MealPlanRepository>(),
      ),
      child: BlocListener<MealPlanDetailBloc, MealPlansDetailState>(
        listener: (context, state) {
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: CommonAppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: "${_format(mealPlan.startDate)} → ${_format(mealPlan.endDate)}",

        actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  context.read<MealPlanNavigatorCubit>().showMealPlanUpdate(mealPlan);
                },
              )
            ],
          ),
          floatingActionButton: Builder(
            builder: (innerContext) => _shoppingListFab(innerContext),
          ),

          body: _mealPlanDetailPage(),
        ),
      ),
    );
  }

  Widget _shoppingListFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {
        context.read<MealPlanDetailBloc>().add(
          GenerateShoppingListEvent(),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Einkaufsliste wurde erstellt'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            showCloseIcon: true,
          ),
        );
      },
      child: const Icon(Icons.add_shopping_cart),
    );
  }




  // MAIN PAGE ------------------------------------------------------------

  Widget _mealPlanDetailPage() {
    return BlocBuilder<MealPlanDetailBloc, MealPlansDetailState>(
      builder: (context, state) {
        if (state is LoadingMealPlansDetailState) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is LoadedMealPlanDetailState) {
          final plan = state.mealPlan;

          if (plan.dailyMealPlans.isEmpty) {
            return const Center(
              child: Text("Derzeit sind keine Essenspläne verfügbar."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plan.dailyMealPlans.length,
            itemBuilder: (context, index) {
              final day = plan.dailyMealPlans[index];
              return _dayCard(context, day);
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  // DAY CARD -------------------------------------------------------------

  Widget _dayCard(BuildContext context, DailyMealPlan day) {
    final date = day.date;
    final weekday = _weekdayLabel(date);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER: date + weekday
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  "$weekday, ${_format(date)}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),

            ...day.meals.entries.map((entry) {
              final mealtime = mealtimeLabel(entry.key.name);
              final meals = entry.value;

              if (meals.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mealtime Label + Icon
                    Row(
                      children: [
                        _mealtimeIcon(mealtime),
                        const SizedBox(width: 6),
                        Text(
                          mealtime,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...meals.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 6),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "${m.recipe.name} • ${m.servings} Portionen",
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // Icons for each meal time ---------------------------------------------

  Icon _mealtimeIcon(String mealTime) {
    switch (mealTime) {
      case "Frühstück":
        return const Icon(Icons.free_breakfast);
      case "Brunch":
        return const Icon(Icons.egg_alt);
      case "Mittagessen":
        return const Icon(Icons.lunch_dining);
      case "Snack":
        return const Icon(Icons.cookie);
      case "Abendessen":
        return const Icon(Icons.dining);
      default:
        return const Icon(Icons.fastfood);
    }
  }




  // Helpers ---------------------------------------------------------------

  String _format(DateTime date) => "${date.day}.${date.month}.";

  String _weekdayLabel(DateTime date) {
    const weekdays = [
      "Montag",
      "Dienstag",
      "Mittwoch",
      "Donnerstag",
      "Freitag",
      "Samstag",
      "Sonntag"
    ];
    return weekdays[date.weekday - 1];
  }
}
