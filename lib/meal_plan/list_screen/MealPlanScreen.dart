import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';


import '../../widgets/AnimatedEmptyState.dart';
import '../../widgets/CommonAppBar.dart';
import '../../widgets/CommonFloatingActionButton.dart';
import '../MealPlanRepository.dart';
import '../domain/MealPlan.dart';
import '../navigation/MealPlanNavigatorCubit.dart';
import 'MealPlanBloc.dart';
import 'MealPlanEvent.dart';
import 'MealPlanState.dart';

class MealPlanScreen extends StatelessWidget {
  const MealPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MealPlanBloc(
        dataRepo: context.read<MealPlanRepository>(),
      )..add(LoadMealPlanEvent()),
      child: Scaffold(
        appBar: CommonAppBar(title: 'Essensplan'),
        floatingActionButton: _floatingActionButton(),
        body: _mealPlansList(),
      ),
    );
  }

  Widget _floatingActionButton() {
    return Builder(
      builder: (context) {
        return CommonFloatingActionButton(
          showNavigator: () => _showCreateMealPlanDialog(context),
          iconData: Icons.add,
          iconSize: 46, iconColor: null, backgroundColor: null,
        );
      },
    );
  }

  Widget _mealPlansList() {
    return BlocBuilder<MealPlanBloc, MealPlanState>(
      builder: (context, state) {
        if (state is LoadingMealPlanState) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is FailedToLoadMealPlanState) {
          return Center(child: Text('Error occurred: ${state.error}'));
        } else if (state is LoadedMealPlanState) {
          final mealPlans = state.mealPlans;

          if (mealPlans.isEmpty) {
            return AnimatedEmptyState(
              icon: Icons.calendar_month,
              message: "Noch keine Essenspläne",
              buttonText: "Essensplan erstellen",
              onPressed: () => _showCreateMealPlanDialog(context),
            );
          }



          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: mealPlans.length,
            itemBuilder: (context, index) {
              final plan = mealPlans[index];

              return Dismissible(
                key: ValueKey(plan.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await _confirmDelete(context, plan);
                },
                onDismissed: (_) {
                  context.read<MealPlanBloc>().add(MealPlanDeleted(plan));
                },
                child: _mealPlanCard(context, plan),
              );

            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, MealPlan plan) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Essensplan wirklich löschen?"),
        content: Text(
          "${_format(plan.startDate)} – ${_format(plan.endDate)} wird gelöscht.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Abbrechen"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Löschen"),
          ),
        ],
      ),
    );
  }


  Widget _mealPlanCard(BuildContext context, MealPlan plan) {
    final days = plan.endDate.difference(plan.startDate).inDays + 1;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
           BlocProvider.of<MealPlanNavigatorCubit>(context)
              .showMealPlanDetail(plan);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.calendar_month, size: 40, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${_format(plan.startDate)} → ${_format(plan.endDate)}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$days Tage • ${plan.dailyMealPlans.length} Tagespläne",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              Icon(Icons.chevron_right, color: Colors.grey[700]),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _showCreateMealPlanDialog(BuildContext context) async {
    DateTime? startDate;
    DateTime? endDate;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text("Essensplan erstellen"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Start Date Picker Button
                  ListTile(
                    title: Text(startDate == null
                        ? "Wähle Startdatum"
                        : "Start: ${_format(startDate!)}"),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                  ),

                  // End Date Picker Button
                  ListTile(
                    title: Text(endDate == null
                        ? "Wähle Enddatum"
                        : "Ende: ${_format(endDate!)}"),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: startDate ?? DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() => endDate = picked);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text("Abbrechen"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (startDate != null && endDate != null) {
                      final newMealPlan = MealPlan(
                        id: 0,
                        startDate: startDate!,
                        endDate: endDate!,
                        dailyMealPlans: [],
                      );

                      Navigator.of(ctx).pop();

                      BlocProvider.of<MealPlanNavigatorCubit>(context)
                          .showCreateMealPlan(newMealPlan);
                    }
                  },
                  child: const Text("OK"),
                ),
              ],
            );
          },
        );
      },
    );
  }



  String _format(DateTime date) {
    return "${date.day}.${date.month}.${date.year}";
  }
}
