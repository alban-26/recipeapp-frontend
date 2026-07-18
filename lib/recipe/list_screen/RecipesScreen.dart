import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../widgets/AnimatedEmptyState.dart';
import '../../widgets/CommonAppBar.dart';
import '../../widgets/CommonFloatingActionButton.dart';
import '../RecipeRepository.dart';
import '../navigation/RecipeNavigatorCubit.dart';
import 'RecipesBloc.dart';
import 'RecipesEvent.dart';
import 'RecipesState.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<bool> _isSearching = ValueNotifier(false);
  final ScrollController _scrollController = ScrollController();

  late final RecipesBloc _recipesBloc;

  @override
  void initState() {
    super.initState();
    _recipesBloc = RecipesBloc(
      dataRepo: context.read<RecipeRepository>(),
    )..add(LoadRecipesEvent());

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    const threshold = 200.0;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - threshold) {
      _recipesBloc.add(LoadMoreRecipesEvent());
    }
  }

  void _closeSearch() {
    _searchController.clear();
    _recipesBloc.add(SearchRecipesEvent(''));
    _isSearching.value = false;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _recipesBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _recipes(context);
  }

  Widget _recipes(BuildContext context) {
    return BlocProvider.value(
      value: _recipesBloc,
      child: BlocListener<RecipesBloc, RecipesState>(
        listener: (context, state) {},
        child: Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: ValueListenableBuilder<bool>(
              valueListenable: _isSearching,
              builder: (context, isSearching, _) {
                return CommonAppBar(
                  title: 'Rezepte',
                  isSearching: isSearching,
                  searchController: _searchController,
                  onSearchChanged: (query) {
                    context.read<RecipesBloc>().add(SearchRecipesEvent(query));
                  },
                  actions: [
                    IconButton(
                      icon: Icon(isSearching ? Icons.close : Icons.search),
                      onPressed: () {
                        if (isSearching) {
                          _closeSearch();
                        } else {
                          _isSearching.value = true;
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
          floatingActionButton: _floatingActionButton(),
          body: _recipesPage(),
        ),
      ),
    );
  }

  Widget _floatingActionButton() {
    return CommonFloatingActionButton(
      showNavigator: () {
        BlocProvider.of<RecipeNavigatorCubit>(context).showCreateRecipe();
      },
      iconData: Icons.add,
      iconColor: null,
      backgroundColor: null,
      iconSize: 46,
    );
  }

  Widget _recipesPage() {
    return BlocBuilder<RecipesBloc, RecipesState>(
      builder: (context, state) {
        if (state is LoadingRecipesState) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is LoadedRecipesState) {
          return Column(
            children: [
              // NEU: dünner Ladebalken während Suche/Refresh/Add/Delete läuft,
              // damit die Liste nicht "eingefroren" wirkt, während im Hintergrund
              // ein neuer Request läuft.
              if (state.isLoadingMore && state.recipes.isNotEmpty)
                const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: state.recipes.isEmpty
                    ? _emptyState(context, state)
                    : _recipeList(context, state),
              ),
            ],
          );
        } else if (state is FailedToLoadRecipesState) {
          return Center(child: Text('Error occurred: ${state.error}'));
        } else {
          return Container();
        }
      },
    );
  }

  // NEU: unterscheidet "keine Rezepte vorhanden" von "keine Suchtreffer"
  Widget _emptyState(BuildContext context, LoadedRecipesState state) {
    final isSearchResult = state.searchQuery.isNotEmpty;
    return AnimatedEmptyState(
      icon: isSearchResult ? Icons.search_off : Icons.fastfood_outlined,
      message: isSearchResult
          ? 'Keine Rezepte für "${state.searchQuery}" gefunden'
          : 'Noch keine Rezepte',
      buttonText: isSearchResult ? null : 'Erstes Rezept erstellen',
      onPressed: isSearchResult
          ? null
          : () => BlocProvider.of<RecipeNavigatorCubit>(context).showCreateRecipe(),
    );
  }

  Widget _recipeList(BuildContext context, LoadedRecipesState state) {
    return RefreshIndicator(
      onRefresh: () async {
        BlocProvider.of<RecipesBloc>(context).add(PullToRefreshEvent());
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: state.recipes.length + (state.hasReachedMax ? 0 : 1),
        itemBuilder: (context, index) {
          if (index >= state.recipes.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final recipe = state.recipes[index];
          return Dismissible(
            key: Key(recipe.id.toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              color: Colors.red,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Icon(Icons.delete, color: Colors.white),
              ),
            ),
            onDismissed: (_) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              BlocProvider.of<RecipesBloc>(context).add(RecipeDeleted(recipe));
            },
            confirmDismiss: (_) async {
              return await showDialog(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: const Text('Rezept löschen'),
                  content: const Text('Bist du sicher, dass du dieses Rezept löschen möchtest?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Abbrechen'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Löschen'),
                    ),
                  ],
                ),
              );
            },
            child: GestureDetector(
              onTap: () {
                BlocProvider.of<RecipeNavigatorCubit>(context).showRecipeDetail(recipe);
              },
              child: Card(
                elevation: 2,
                color: Colors.white,
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 120.0,
                        height: 120.0,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16.0),
                            bottomLeft: Radius.circular(16.0),
                          ),
                          color: Colors.grey[200],
                        ),
                        child: recipe.image != null
                            ? Image.memory(recipe.image!, fit: BoxFit.cover)
                            : const Icon(Icons.fastfood, size: 50, color: Colors.grey),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                recipe.name,
                                style: const TextStyle(
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${recipe.duration.inMinutes} min',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}