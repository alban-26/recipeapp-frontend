import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';
import 'package:recipeapp_frontend/recipe/RecipeRepository.dart';

import 'RecipesEvent.dart';
import 'RecipesState.dart';

/// Debounced für normale Tippgeschwindigkeit, aber ein leerer Suchbegriff
/// (z.B. durch den X-Button) wird sofort verarbeitet, ohne Verzögerung.
/// switchMap sorgt zusätzlich dafür, dass bei schnellem Weitertippen nur
/// die Antwort der letzten Suche berücksichtigt wird (verhindert, dass eine
/// spät zurückkommende alte Antwort eine neuere überschreibt).
EventTransformer<SearchRecipesEvent> _searchTransformer(Duration duration) {
  return (events, mapper) => events.switchMap((event) {
    if (event.query.isEmpty) {
      return mapper(event);
    }
    return Stream.value(event).debounce(duration).switchMap(mapper);
  });
}

class RecipesBloc extends Bloc<RecipesEvent, RecipesState> {
  final RecipeRepository dataRepo;
  static const int _pageSize = 20;
  static const Duration _searchDebounce = Duration(milliseconds: 400);

  RecipesBloc({required this.dataRepo}) : super(LoadingRecipesState()) {
    on<LoadRecipesEvent>(_onLoad);
    on<LoadMoreRecipesEvent>(_onLoadMore);
    on<SearchRecipesEvent>(_onSearch, transformer: _searchTransformer(_searchDebounce));
    on<PullToRefreshEvent>(_onPullToRefresh);
    on<AddRecipeEvent>(_onAdd);
    on<RecipeDeleted>(_onDelete);
  }

  String _currentQuery() {
    final s = state;
    return s is LoadedRecipesState ? s.searchQuery : '';
  }

  /// Lädt Page 0 für die übergebene Query. Wird von Load, Search, Refresh,
  /// Add und Delete gemeinsam genutzt, damit das Verhalten überall konsistent ist.
  Future<void> _fetchFirstPage(
      Emitter<RecipesState> emit, {
        required String query,
        required bool showFullScreenLoading,
      }) async {
    final currentState = state;
    if (showFullScreenLoading || currentState is! LoadedRecipesState) {
      emit(LoadingRecipesState());
    } else {
      emit(currentState.copyWith(isLoadingMore: true));
    }

    try {
      final page = await dataRepo.fetchRecipes(
        page: 0,
        size: _pageSize,
        query: query.isEmpty ? null : query,
      );
      emit(
        LoadedRecipesState(
          recipes: page.content,
          currentPage: page.page,
          hasReachedMax: page.last,
          searchQuery: query,
        ),
      );
    } catch (exception) {
      emit(FailedToLoadRecipesState(error: exception));
    }
  }

  /// 🔄 Initial Load
  Future<void> _onLoad(RecipesEvent event, Emitter<RecipesState> emit) async {
    await _fetchFirstPage(emit, query: '', showFullScreenLoading: true);
  }

  /// ⬇️ Load More (Infinite Scroll) — behält aktuelle Suche bei
  Future<void> _onLoadMore(RecipesEvent event, Emitter<RecipesState> emit) async {
    final currentState = state;
    if (currentState is! LoadedRecipesState) return;
    if (currentState.hasReachedMax || currentState.isLoadingMore) return;

    emit(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = currentState.currentPage + 1;
      final query = currentState.searchQuery;
      final page = await dataRepo.fetchRecipes(
        page: nextPage,
        size: _pageSize,
        query: query.isEmpty ? null : query,
      );

      emit(
        currentState.copyWith(
          recipes: List.of(currentState.recipes)..addAll(page.content),
          currentPage: page.page,
          hasReachedMax: page.last,
          isLoadingMore: false,
        ),
      );
    } catch (exception) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  /// 🔍 Search — läuft server-seitig, debounced (siehe _searchTransformer)
  Future<void> _onSearch(SearchRecipesEvent event, Emitter<RecipesState> emit) async {
    await _fetchFirstPage(emit, query: event.query, showFullScreenLoading: false);
  }

  /// ⬇ Pull To Refresh — aktuelle Suche bleibt erhalten
  Future<void> _onPullToRefresh(RecipesEvent event, Emitter<RecipesState> emit) async {
    await _fetchFirstPage(emit, query: _currentQuery(), showFullScreenLoading: false);
  }

  /// ➕ Add Recipe — Liste neu laden, aktuelle Suche bleibt erhalten
  Future<void> _onAdd(RecipesEvent event, Emitter<RecipesState> emit) async {
    await _fetchFirstPage(emit, query: _currentQuery(), showFullScreenLoading: false);
  }

  /// 🗑 Delete Recipe — löschen, dann neu laden, aktuelle Suche bleibt erhalten
  Future<void> _onDelete(RecipeDeleted event, Emitter<RecipesState> emit) async {
    final query = _currentQuery();
    try {
      await dataRepo.removeRecipe(event.recipe.id);
    } catch (exception) {
      emit(FailedToLoadRecipesState(error: exception));
      return;
    }
    await _fetchFirstPage(emit, query: query, showFullScreenLoading: false);
  }
}