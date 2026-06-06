import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../widgets/CommonAppBar.dart';
import '../MealPlanRepository.dart';
import '../domain/DailyMealPlan.dart';
import '../domain/Meal.dart';
import '../domain/MealPlan.dart';
import '../domain/Mealtime.dart';
import '../domain/RecipeRef.dart';
import '../navigation/MealPlanNavigatorCubit.dart';
import 'CreateMealPlanBloc.dart';
import 'CreateMealPlanEvent.dart';
import 'CreateMealPlanState.dart';

class CreateMealPlanScreen extends StatelessWidget {
  final MealPlan mealPlan;
  final bool isEditing;

  const CreateMealPlanScreen({
    super.key,
    required this.mealPlan,
    this.isEditing = false,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) {
        final bloc = CreateMealPlanBloc(
          initialMealPlan: mealPlan,
          repo: ctx.read<MealPlanRepository>(),
          isEditing: isEditing,
        );

        if (!isEditing) {
          bloc.add(GenerateDailyMealPlans());
        }

        return bloc;
      },
      child: BlocConsumer<CreateMealPlanBloc, CreateMealPlansState>(
        listener: (context, state) {
          if (state is CreateMealPlanSaved) {
            context.read<MealPlanNavigatorCubit>().showMealPlans();
          }
        },
        builder: (context, state) {
          if (state is CreateMealPlanInitial || state is CreateMealPlanLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is CreateMealPlanLoaded) {
            return Scaffold(
              appBar: CommonAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: isEditing ? "Essensplan bearbeiten" : "Essensplan erstellen",
              ),

              floatingActionButton: FloatingActionButton.extended(
                icon: const Icon(Icons.save),
                label: const Text("Speichern"),
                onPressed: () =>
                    context.read<CreateMealPlanBloc>().add(SaveMealPlan()),
              ),

              body: _buildMealPlanList(context, state),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // =====================================================================
  // MAIN LIST VIEW
  // =====================================================================

  Widget _buildMealPlanList(BuildContext context, CreateMealPlanLoaded state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...state.mealPlan.dailyMealPlans
            .map((day) => _dayCard(context, state, day)),
      ],
    );
  }

  // =====================================================================
  // DAY CARD UI
  // =====================================================================

  Widget _dayCard(
      BuildContext context,
      CreateMealPlanLoaded state,
      DailyMealPlan day,
      ) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dayHeader(context, day),

            const Divider(height: 28),

            ...Mealtime.values.map(
                  (mealtime) => _mealtimeSection(
                context,
                state,
                day,
                mealtime,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayHeader(BuildContext context, DailyMealPlan day) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "${day.date.day}.${day.date.month}.${day.date.year}",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () {
            context
                .read<CreateMealPlanBloc>()
                .add(RemoveDailyMealPlan(day.id));
          },
        ),
      ],
    );
  }

  // =====================================================================
  // MEALTIME SECTION
  // =====================================================================

  Widget _mealtimeSection(
      BuildContext context,
      CreateMealPlanLoaded state,
      DailyMealPlan day,
      Mealtime mealtime,
      ) {
    final meals = day.meals[mealtime] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mealtime.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[700],
            ),
          ),

          const SizedBox(height: 6),

          ...meals.map((meal) => _mealItem(context, meal, day, mealtime)),

          AddMealForm(
            state: state,
            day: day,
            mealtime: mealtime,
          ),
        ],
      ),
    );
  }

  Widget _mealItem(
      BuildContext context,
      Meal meal,
      DailyMealPlan day,
      Mealtime mealtime,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("${meal.recipe.name} (${meal.servings})"),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              context.read<CreateMealPlanBloc>().add(
                RemoveMealFromDay(
                  dailyId: day.id,
                  mealtime: mealtime,
                  meal: meal,
                ),
              );
            },
          )
        ],
      ),
    );
  }
}

// ========================== NEUES STATEFULWIDGET AddMealForm ==========================

class AddMealForm extends StatefulWidget {
  final CreateMealPlanLoaded state;
  final DailyMealPlan day;
  final Mealtime mealtime;

  const AddMealForm({
    super.key,
    required this.state,
    required this.day,
    required this.mealtime,
  });

  @override
  State<AddMealForm> createState() => _AddMealFormState();
}

class _AddMealFormState extends State<AddMealForm> {
  RecipeRef? selectedRecipe;
  int servings = 1;
  String currentText = "";

  // controller NICHT mehr selbst erstellen — Autocomplete verwaltet ihn

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<RecipeRef>(
          optionsBuilder: (textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<RecipeRef>.empty();
            }
            return widget.state.availableRecipes.where(
                  (r) => r.name.toLowerCase().contains(textEditingValue.text.toLowerCase()),
            );
          },
          displayStringForOption: (r) => r.name,
          onSelected: (r) {
            setState(() {
              selectedRecipe = r;
              currentText = r.name;
            });
          },
          fieldViewBuilder: (context, textController, focusNode, _) {
            // NICHT mehr: controller = textController
            return TextField(
              controller: textController,
              focusNode: focusNode,
              onChanged: (value) {
                setState(() {
                  currentText = value;
                  selectedRecipe = null;
                });
              },
              decoration: const InputDecoration(
                hintText: "Rezept suchen oder Freitext eingeben…",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            DropdownButton<int>(
              value: servings,
              items: [1, 2, 3, 4, 5]
                  .map((e) => DropdownMenuItem(
                value: e,
                child: Text("$e Portion${e > 1 ? 'en' : ''}"),
              ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => servings = v);
              },
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Hinzufügen"),
              onPressed: currentText.trim().isEmpty
                  ? null
                  : () {
                final recipe = selectedRecipe ??
                    RecipeRef(id: 0, name: currentText.trim());
                context.read<CreateMealPlanBloc>().add(
                  AddMealToDay(
                    dailyId: widget.day.id,
                    mealtime: widget.mealtime,
                    recipe: recipe,
                    servings: servings,
                  ),
                );
                setState(() {
                  selectedRecipe = null;
                  currentText = "";
                  servings = 1;
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}