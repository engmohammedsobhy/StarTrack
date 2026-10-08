import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/entity_model.dart';
import '../../data/repositories/knowledge_repository.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';
import 'user_interests_provider.dart';

final trendingEntitiesProvider = AsyncNotifierProvider<TrendingEntitiesNotifier, List<KnowledgeEntity>>(
  () => TrendingEntitiesNotifier(),
);

final refreshCountProvider = StateProvider<int>((ref) => 0);

class TrendingEntitiesNotifier extends AsyncNotifier<List<KnowledgeEntity>> {
  bool _isFetching = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  int _sessionTimestamp = DateTime.now().millisecondsSinceEpoch;

  bool get isFetching => _isFetching;
  bool get isLoadingMore => _isLoadingMore;
  int get currentPage => _currentPage;
  bool get hasMore => true;

  @override
  Future<List<KnowledgeEntity>> build() async {
    _currentPage = 1;
    _sessionTimestamp = DateTime.now().millisecondsSinceEpoch;
    _isFetching = false;
    _isLoadingMore = false;
    return _fetchPersonalizedFeed(page: _currentPage);
  }

  Future<List<KnowledgeEntity>> _fetchPersonalizedFeed({
    required int page,
    bool refresh = false,
  }) async {
    final repo = ref.read(knowledgeRepositoryProvider);
    final favorites = ref.read(favoritesProvider);
    final interests = ref.read(userInterestsProvider);

    final likedTitles = favorites.map((e) => e.title).toList();
    final viewedTitles = interests.viewedPersonas.map((e) => e.title).toList();
    final searchedQueries = interests.recentSearches;

    final hasInterests =
        likedTitles.isNotEmpty || viewedTitles.isNotEmpty || searchedQueries.isNotEmpty;

    final discoverEntities = await repo.getTrendingEntities(
      page: page,
      refresh: refresh,
      sessionTimestamp: _sessionTimestamp,
    );

    if (!hasInterests || page > 2) {
      return discoverEntities;
    }

    try {
      final recs = await repo.getRecommendations(
        likedTitles,
        viewedPersonas: viewedTitles,
        searchedQueries: searchedQueries,
        limit: 6,
      );

      if (recs.isNotEmpty) {
        final Set<String> seen = {};
        final List<KnowledgeEntity> combined = [];

        int rIdx = 0;
        int dIdx = 0;
        while (rIdx < recs.length || dIdx < discoverEntities.length) {
          if (rIdx < recs.length) {
            final r = recs[rIdx++];
            if (!seen.contains(r.title.toLowerCase())) {
              seen.add(r.title.toLowerCase());
              combined.add(r);
            }
          }
          if (dIdx < discoverEntities.length) {
            final d = discoverEntities[dIdx++];
            if (!seen.contains(d.title.toLowerCase())) {
              seen.add(d.title.toLowerCase());
              combined.add(d);
            }
          }
        }
        return combined;
      }
    } catch (_) {}

    return discoverEntities;
  }

  Future<void> forceRefresh() async {
    state = AsyncLoading<List<KnowledgeEntity>>().copyWithPrevious(state);
    ref.read(refreshCountProvider.notifier).state++;
    _currentPage = 1;
    _sessionTimestamp = DateTime.now().millisecondsSinceEpoch;
    _isFetching = false;
    _isLoadingMore = false;
    state = await AsyncValue.guard(() => _fetchPersonalizedFeed(
      page: _currentPage,
      refresh: true,
    ));
  }

  Future<void> loadMore() async {
    if (_isFetching || _isLoadingMore) return;
    _isLoadingMore = true;
    
    final currentList = state.value ?? [];
    state = AsyncData(List.from(currentList));

    try {
      _currentPage++;
      final newEntities = await _fetchPersonalizedFeed(
        page: _currentPage,
      );
      final latestList = state.value ?? currentList;
      
      final existingTitles = latestList.map((e) => e.title.toLowerCase()).toSet();
      final existingIds = latestList.map((e) => e.id).toSet();
      
      final uniqueNew = newEntities.where((e) {
        return !existingTitles.contains(e.title.toLowerCase()) && !existingIds.contains(e.id);
      }).toList();

      state = AsyncData([...latestList, ...uniqueNew]);
    } catch (e) {
      state = AsyncData(state.value ?? currentList);
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> fetchNextPage() => loadMore();
}
