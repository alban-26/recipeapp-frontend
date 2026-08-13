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
    on<LoadTagsEvent>(_onLoadTags);
    on<FilterByTagsEvent>(_onFilterByTags);
  }
  /// 🏷 Lädt die vom User verwendeten Tags für die Filter-Auswahl.
  Future<void> _onLoadTags(LoadTagsEvent event, Emitter<RecipesState> emit) async {
    try {
      final tags = await dataRepo.fetchTags();

      final currentState = state;
      if (currentState is LoadedRecipesState) {
        emit(currentState.copyWith(availableTags: tags));
      }
      // Wenn der State (noch) nicht Loaded ist, ignorieren wir es hier –
      // die Tags werden beim nächsten LoadTagsEvent nachgezogen.
    } catch (_) {
      // Tag-Liste ist "nice to have" – ein Fehler hier soll die
      // Rezept-Anzeige nicht in einen Fehlerzustand versetzen.
    }
  }


  /// 🔖 Neuer Tag-Filter gesetzt — Liste neu laden, aktuelle Suche bleibt erhalten.
  Future<void> _onFilterByTags(
      FilterByTagsEvent event, Emitter<RecipesState> emit) async {
    await _fetchFirstPage(
      emit,
      query: _currentQuery(),   // aktuelle Suche beibehalten
      tags: event.tags,         // neue Tag-Auswahl
      showFullScreenLoading: false,
    );
  }




  String _currentQuery() {
    final s = state;
    return s is LoadedRecipesState ? s.searchQuery : '';
  }

  List<String> _currentTags() {                       // NEU
    final s = state;
    return s is LoadedRecipesState ? s.tags : const [];
  }

  /// Lädt Page 0 für die übergebene Query. Wird von Load, Search, Refresh,
  /// Add und Delete gemeinsam genutzt, damit das Verhalten überall konsistent ist.
  Future<void> _fetchFirstPage(
      Emitter<RecipesState> emit, {
        required String query,
        required List<String> tags,
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
        tags: tags.isEmpty ? null : tags,   // NEU
      );
      emit(
        LoadedRecipesState(
          recipes: page.content,
          currentPage: page.page,
          hasReachedMax: page.last,
          searchQuery: query,
          tags: tags,
        ),
      );
    } catch (exception) {
      emit(FailedToLoadRecipesState(error: exception));
    }
  }

  Future<void> _onLoad(RecipesEvent event, Emitter<RecipesState> emit) async {
    await _fetchFirstPage(emit, query: '', tags: const [], showFullScreenLoading: true);
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
      final tags = currentState.tags;        // NEU
      final page = await dataRepo.fetchRecipes(
        page: nextPage,
        size: _pageSize,
        query: query.isEmpty ? null : query,
        tags: tags.isEmpty ? null : tags,     // NEU
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
    await _fetchFirstPage(
      emit,
      query: event.query,
      tags: _currentTags(),           // NEU – Tag-Filter bleibt bei Suche erhalten
      showFullScreenLoading: false,
    );
  }

  /// ⬇ Pull To Refresh — aktuelle Suche + Tags bleiben erhalten
  Future<void> _onPullToRefresh(RecipesEvent event, Emitter<RecipesState> emit) async {
    await _fetchFirstPage(
      emit,
      query: _currentQuery(),
      tags: _currentTags(),           // NEU
      showFullScreenLoading: false,
    );
  }

  /// ➕ Add Recipe — Liste neu laden, aktuelle Suche + Tags bleiben erhalten
  Future<void> _onAdd(RecipesEvent event, Emitter<RecipesState> emit) async {
    await _fetchFirstPage(
      emit,
      query: _currentQuery(),
      tags: _currentTags(),           // NEU
      showFullScreenLoading: false,
    );
  }

  /// 🗑 Delete Recipe — löschen, dann neu laden, aktuelle Suche bleibt erhalten
  /// 🗑 Delete Recipe — löschen, dann neu laden, aktuelle Suche + Tags bleiben erhalten
  Future<void> _onDelete(RecipeDeleted event, Emitter<RecipesState> emit) async {
    final query = _currentQuery();
    final tags = _currentTags();          // NEU
    try {
      await dataRepo.removeRecipe(event.recipe.id);
    } catch (exception) {
      emit(FailedToLoadRecipesState(error: exception));
      return;
    }
    await _fetchFirstPage(
      emit,
      query: query,
      tags: tags,                         // NEU
      showFullScreenLoading: false,
    );
  }
}