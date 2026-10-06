import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/entity_model.dart';
import '../../data/repositories/knowledge_repository.dart';

final trendingEntitiesProvider = AsyncNotifierProvider<TrendingEntitiesNotifier, List<KnowledgeEntity>>(
  () => TrendingEntitiesNotifier(),
);

final refreshCountProvider = StateProvider<int>((ref) => 0);

class TrendingEntitiesNotifier extends AsyncNotifier<List<KnowledgeEntity>> {
  bool _isFetching = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;

  bool get isFetching => _isFetching;
  bool get isLoadingMore => _isLoadingMore;
  int get currentPage => _currentPage;
  bool get hasMore => true;

  @override
  Future<List<KnowledgeEntity>> build() async {
    _currentPage = 1;
    _isFetching = false;
    _isLoadingMore = false;
    return ref.read(knowledgeRepositoryProvider).getTrendingEntities(page: _currentPage);
  }

  Future<void> forceRefresh() async {
    state = const AsyncLoading();
    ref.read(refreshCountProvider.notifier).state++;
    _currentPage = 1;
    _isFetching = false;
    _isLoadingMore = false;
    state = await AsyncValue.guard(() => ref.read(knowledgeRepositoryProvider).getTrendingEntities(page: _currentPage, refresh: true));
  }

  Future<void> loadMore() async {
    if (_isFetching || _isLoadingMore) return;
    _isLoadingMore = true;
    
    final currentList = state.value ?? [];
    state = AsyncData(List.from(currentList));

    try {
      _currentPage++;
      final newEntities = await ref.read(knowledgeRepositoryProvider).getTrendingEntities(page: _currentPage);
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
