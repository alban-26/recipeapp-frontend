import 'package:flutter/material.dart';

class RecipeSearchDelegate extends SearchDelegate {
  final List recipes;

  RecipeSearchDelegate({required this.recipes});

  @override
  String get searchFieldLabel => 'Rezept suchen';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results = recipes
        .where((recipe) =>
        recipe.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return _buildList(results);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final results = recipes
        .where((recipe) =>
        recipe.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return _buildList(results);
  }

  Widget _buildList(List results) {
    if (results.isEmpty) {
      return const Center(child: Text('Keine Rezepte gefunden'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final recipe = results[index];
        return ListTile(
          title: Text(recipe.name),
          onTap: () {
            close(context, recipe);
          },
        );
      },
    );
  }
}
