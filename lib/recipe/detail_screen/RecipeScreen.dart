import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../domain/CookingInstruction.dart';
import '../domain/Recipe.dart';
import '../navigation/RecipeNavigatorCubit.dart';
import 'RecipeBloc.dart';
import 'RecipeEvent.dart';
import '../../widgets/WakelockToggle.dart';

class RecipeScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RecipeBloc(recipe: recipe),
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Theme.of(context).primaryColor,
              flexibleSpace: FlexibleSpaceBar(
                title: SizedBox(
                  width: 200,
                  child: Text(
                    recipe.name,
                    style: const TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    recipe.image != null
                        ? Image.memory(
                            recipe.image!,
                            fit: BoxFit.cover,
                          )
                        : Container(color: Colors.grey),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.center,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                            // Adjust the opacity and color
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    BlocProvider.of<RecipeNavigatorCubit>(context)
                        .updateRecipe(recipe);
                  },
                ),
              ],
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  if (index == 0) {
                    return Column(
                      children: [
                        _portionsAndDuration(),
                        _buildTags(context),
                      ],
                    );
                  } else if (index == 1) {
                    return _buildSectionHeader('Zutaten');
                  } else if (index > 1 &&
                      index <= recipe.recipeIngredients.length + 1) {
                    return _buildIngredientItem(index - 2,
                        index - recipe.recipeIngredients.length - 2, context);
                  } else if (index == recipe.recipeIngredients.length + 2) {
                    return _buildSectionHeader('Zubereitung');
                  } else {
                    return _buildDescriptionItem(
                        recipe
                            .cookingInstructions[
                                index - recipe.recipeIngredients.length - 3],
                        index - recipe.recipeIngredients.length - 2,
                        context);
                  }
                },
                childCount: 3 +
                    recipe.recipeIngredients.length +
                    recipe.cookingInstructions.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTags(BuildContext context) {
    if (recipe.tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recipe.tags.map((tag) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tag,
                    size: 14,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _portionsAndDuration() {
    return BlocBuilder<RecipeBloc, RecipeDetailState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                FontAwesomeIcons.bowlRice,
                size: 35,
              ),
              IconButton(
                icon: Icon(Icons.remove_circle_outline,
                    color: Colors.grey.shade600),
                // Icon for decrementing
                onPressed: () {
                  if (state.recipe.portions > 1) {
                    context.read<RecipeBloc>().add(DecrementPortions());
                  }
                },
              ),
              Text(
                '${state.recipe.portions}',
                style: TextStyle(
                  fontSize: 17.0, // Replace with your desired font size
                  color: Theme.of(context)
                      .primaryColor, // Replace with your desired text color
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey.shade600,
                ),
                // Icon for incrementing
                onPressed: () {
                  context.read<RecipeBloc>().add(IncrementPortions());
                },
              ),
              const SizedBox(
                width: 20,
              ),
              const Icon(
                Icons.access_time_rounded,
                size: 30,
              ),
              const SizedBox(
                width: 5,
              ),
              Text(
                '${state.recipe.duration.inMinutes} min',
                style: TextStyle(
                  fontSize: 17.0, // Replace with your desired font size
                  color: Theme.of(context)
                      .primaryColor, // Replace with your desired text color
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              const WakelockToggle(),
              //_buildNumberPicker(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String headerText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        headerText,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildIngredientItem(int index, int stepNumber, BuildContext context) {
    final isEven = stepNumber % 2 == 0;
    final backgroundColor =
        isEven ? Colors.grey.shade50 : Theme.of(context).colorScheme.surface;
    return BlocBuilder<RecipeBloc, RecipeDetailState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${state.recipe.recipeIngredients[index].quantity} ${state.recipe.recipeIngredients[index].unit}',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 26),
                  Expanded(
                    flex: 3,
                    child: Text(
                      recipe.recipeIngredients[index].name,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDescriptionItem(
      CookingInstruction instruction, int stepNumber, BuildContext context) {
    final isEven = stepNumber % 2 == 0;
    final backgroundColor =
    isEven ? Colors.grey.shade50 : Theme.of(context).colorScheme.surface;
    final ingredients = instruction.recipeIngredients;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$stepNumber. Schritt',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (ingredients.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final ing in ingredients)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _ingredientLabel(ing.quantity, ing.unit, ing.name),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                instruction.instruction,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _ingredientLabel(double quantity, String unit, String name) {
    final qStr = quantity <= 0
        ? ''
        : (quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString());
    final parts =
    [qStr, unit, name].where((s) => s.trim().isNotEmpty).toList();
    return parts.join(' ');
  }
}
