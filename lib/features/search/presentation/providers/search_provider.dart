import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';
import 'package:itiproject/features/home/data/repositories/knowledge_repository.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final homeSearchOpenProvider = StateProvider<bool>((ref) => false);

/// Multi-label filter: ordered list of selected labels (empty = no label filter)
final selectedSearchLabelsProvider = StateProvider<List<String>>((ref) => []);

/// Single-label alias kept for person_details_screen compatibility
final selectedSearchLabelProvider = StateProvider<String?>((ref) => null);

final selectedFilterChipProvider = StateProvider<String>((ref) => 'All');

// ─── Paginated Search Results Notifier ───────────────────────────────────────

class SearchResultsState {
  final List<KnowledgeEntity> results;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;

  const SearchResultsState({
    this.results = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  SearchResultsState copyWith({
    List<KnowledgeEntity>? results,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) {
    return SearchResultsState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class SearchResultsNotifier extends StateNotifier<SearchResultsState> {
  final KnowledgeRepository _repository;

  static const int _pageSize = 20;
  int _currentPage = 0;
  String _lastQuery = '';
  List<String> _lastLabels = [];

  // Full result cache for the current query/labels (before pagination slicing)
  List<KnowledgeEntity> _allResults = [];

  SearchResultsNotifier(this._repository) : super(const SearchResultsState());

  /// Called whenever query or labels change — resets and shows first page
  Future<void> search(String query, List<String> labels) async {
    final trimQuery = query.trim();
    final bool isEmpty = trimQuery.isEmpty && labels.isEmpty;

    if (_lastQuery == trimQuery && _sameLabels(labels)) return;
    _lastQuery = trimQuery;
    _lastLabels = List.from(labels);
    _currentPage = 0;
    _allResults = [];

    if (isEmpty) {
      state = const SearchResultsState();
      return;
    }

    state = state.copyWith(isLoading: true, results: [], hasMore: true, error: null);

    try {
      _allResults = await _fetchAll(trimQuery, labels);
      if (!mounted) return;
      final firstPage = _slice(0);
      state = SearchResultsState(
        results: firstPage,
        isLoading: false,
        hasMore: firstPage.length < _allResults.length,
      );
    } catch (e) {
      if (!mounted) return;
      state = SearchResultsState(error: e.toString());
    }
  }

  /// Load next page (infinite scroll)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);

    final nextPage = _currentPage + 1;
    final more = _slice(nextPage);
    if (!mounted) return;

    if (more.isEmpty) {
      state = state.copyWith(isLoadingMore: false, hasMore: false);
      return;
    }

    _currentPage = nextPage;
    state = state.copyWith(
      results: [...state.results, ...more],
      isLoadingMore: false,
      hasMore: (_currentPage + 1) * _pageSize < _allResults.length,
    );
  }

  List<KnowledgeEntity> _slice(int page) {
    final start = page * _pageSize;
    if (start >= _allResults.length) return [];
    final end = (start + _pageSize).clamp(0, _allResults.length);
    return _allResults.sublist(start, end);
  }

  Future<List<KnowledgeEntity>> _fetchAll(String query, List<String> labels) async {
    if (labels.isNotEmpty) {
      // Fetch per label then intersect
      final List<List<KnowledgeEntity>> perLabel = [];
      for (final label in labels) {
        final res = await _repository.getPersonasByLabel(label, filterQuery: query);
        perLabel.add(res);
      }
      if (perLabel.isEmpty) return [];
      var intersected = perLabel.first;
      for (final next in perLabel.skip(1)) {
        final nextTitles = next.map((e) => e.title.toLowerCase()).toSet();
        intersected = intersected.where((e) => nextTitles.contains(e.title.toLowerCase())).toList();
      }
      return intersected;
    }
    return _repository.searchEntities(query);
  }

  bool _sameLabels(List<String> other) {
    if (_lastLabels.length != other.length) return false;
    for (int i = 0; i < _lastLabels.length; i++) {
      if (_lastLabels[i] != other[i]) return false;
    }
    return true;
  }
}

final searchResultsNotifierProvider =
    StateNotifierProvider<SearchResultsNotifier, SearchResultsState>((ref) {
  final repo = ref.read(knowledgeRepositoryProvider);
  return SearchResultsNotifier(repo);
});

// Legacy FutureProvider — kept for backwards compat
final searchResultsProvider = FutureProvider<List<KnowledgeEntity>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final selectedLabel = ref.watch(selectedSearchLabelProvider);

  if (query.isEmpty && (selectedLabel == null || selectedLabel.isEmpty)) {
    return [];
  }

  if (query.isNotEmpty) {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  final repository = ref.read(knowledgeRepositoryProvider);
  if (selectedLabel != null && selectedLabel.isNotEmpty) {
    return repository.getPersonasByLabel(selectedLabel, filterQuery: query);
  }

  return repository.searchEntities(query);
});

final curatedCategorySectionProvider =
    FutureProvider.family<List<KnowledgeEntity>, List<String>>((ref, names) async {
  final repository = ref.read(knowledgeRepositoryProvider);
  final List<KnowledgeEntity> entities = [];
  for (final name in names) {
    try {
      final list = await repository.searchEntities(name);
      if (list.isNotEmpty) entities.add(list.first);
    } catch (_) {}
  }
  return entities;
});

final searchTrendingGridProvider = FutureProvider<List<KnowledgeEntity>>((ref) async {
  final filter = ref.watch(selectedFilterChipProvider);
  final repository = ref.read(knowledgeRepositoryProvider);

  if (filter == 'All') {
    return repository.getTrendingEntities(page: 1, refresh: true);
  }

  final String queryTerm;
  switch (filter) {
    case 'Actors':
      queryTerm = 'Famous Hollywood actors';
      break;
    case 'Musicians':
      queryTerm = 'Famous singers musicians';
      break;
    case 'Scientists':
      queryTerm = 'Famous scientific geniuses physicists';
      break;
    case 'Athletes':
      queryTerm = 'Famous athletes football basketball';
      break;
    case 'Philosophers':
      queryTerm = 'Famous ancient modern philosophers';
      break;
    case 'World Leaders':
      queryTerm = 'Famous world leaders presidents statesmen';
      break;
    case 'Historians':
      queryTerm = 'Famous historians historical figures';
      break;
    default:
      queryTerm = filter;
  }

  return repository.searchEntities(queryTerm);
});

