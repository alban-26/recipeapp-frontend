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
    )..add(LoadRecipesEvent())
      ..add(LoadTagsEvent()
    );

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
                  leading: _buildFilterLeading(),   // NEU
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

  // ── Aktive Filter als entfernbare Chips (horizontal scrollbar) ────────────
  Widget _activeTagChips(BuildContext context, LoadedRecipesState state) {
    if (state.tags.isEmpty) return const SizedBox.shrink();
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.tags.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final tag = state.tags[i];
          return InputChip(
            label: Text(tag),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
            backgroundColor: primary.withOpacity(0.1),
            side: BorderSide(color: primary.withOpacity(0.35)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            deleteIcon: Icon(Icons.close, size: 16, color: primary),
            onDeleted: () => _removeTag(context, state, tag),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  void _removeTag(
      BuildContext context, LoadedRecipesState state, String tag) {
    final updated = List<String>.from(state.tags)..remove(tag);
    context.read<RecipesBloc>().add(FilterByTagsEvent(updated));
  }

// ── Das Bottom-Sheet zur Tag-Auswahl ─────────────────────────────────────
  void _openTagFilterSheet(BuildContext context, LoadedRecipesState state) {
    final bloc = context.read<RecipesBloc>();       // vor dem Sheet greifen!
    final selected = Set<String>.from(state.tags);  // lokale Temp-Auswahl
    final primary = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag-Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Nach Tags filtern',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      AnimatedOpacity(
                        opacity: selected.isEmpty ? 0.4 : 1,
                        duration: const Duration(milliseconds: 150),
                        child: TextButton(
                          onPressed: selected.isEmpty
                              ? null
                              : () => setSheetState(selected.clear),
                          child: const Text('Zurücksetzen'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Chips oder Leer-Hinweis
                  if (state.availableTags.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Noch keine Tags vorhanden',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: state.availableTags.map((tag) {
                            final isSel = selected.contains(tag);
                            return FilterChip(
                              label: Text(tag),
                              selected: isSel,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSel ? Colors.white : primary,
                              ),
                              backgroundColor: primary.withOpacity(0.08),
                              selectedColor: primary,
                              side: BorderSide(
                                color: isSel
                                    ? primary
                                    : primary.withOpacity(0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              onSelected: (v) => setSheetState(() {
                                v ? selected.add(tag) : selected.remove(tag);
                              }),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Anwenden
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        bloc.add(FilterByTagsEvent(selected.toList()));
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(
                        selected.isEmpty
                            ? 'Anwenden'
                            : 'Anwenden (${selected.length})',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Filter-Button für die AppBar (leading, oben links) ───────────────────
  Widget _buildFilterLeading() {
    return BlocBuilder<RecipesBloc, RecipesState>(
      bloc: _recipesBloc,
      builder: (context, state) {
        final count = state is LoadedRecipesState ? state.tags.length : 0;
        final active = count > 0;
        final onPrimary = Theme.of(context).colorScheme.onSurface;

        return IconButton(
          tooltip: 'Filter',
          onPressed: state is LoadedRecipesState
              ? () => _openTagFilterSheet(context, state)
              : null,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.tune_rounded, color: onPrimary),
              if (active)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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

  // ── Schmale Leiste mit aktiven Filter-Chips (klappt weg wenn leer) ───────
  Widget _activeFilterBar(BuildContext context, LoadedRecipesState state) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: state.tags.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: _activeTagChips(context, state),
      ),
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
              _activeFilterBar(context, state),   // NEU – nur aktive Chips
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // --- Tags ---
                              if (recipe.tags.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: recipe.tags.take(3).map((tag) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondaryContainer
                                            .withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSecondaryContainer,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],

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