import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:itiproject/core/services/persona_label_service.dart';
import 'package:itiproject/core/widgets/entity_card.dart';
import 'package:itiproject/core/widgets/persona_label_chip.dart';
import 'package:itiproject/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';
import 'package:itiproject/features/search/presentation/providers/search_provider.dart';
import '../providers/entity_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _searchController = TextEditingController(text: ref.read(searchQueryProvider));
    _searchFocusNode = FocusNode();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    setState(() {});
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      if (maxScroll > 0 && currentScroll >= maxScroll - 400) {
        final notifier = ref.read(trendingEntitiesProvider.notifier);
        if (!notifier.isLoadingMore) {
          notifier.loadMore();
        }
      }
    }
  }

  void _openSearch() {
    ref.read(homeSearchOpenProvider.notifier).state = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeSearch() {
    ref.read(homeSearchOpenProvider.notifier).state = false;
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final entitiesAsyncValue = ref.watch(trendingEntitiesProvider);
    final favorites = ref.watch(favoritesProvider);
    final isLoadingMore = ref.read(trendingEntitiesProvider.notifier).isLoadingMore;
    final isSearchOpen = ref.watch(homeSearchOpenProvider);
    final searchQuery = ref.watch(searchQueryProvider).trim();

    // Listen to external query updates (e.g., from persona details label tap)
    ref.listen<String>(searchQueryProvider, (previous, next) {
      if (_searchController.text != next) {
        _searchController.text = next;
      }
    });

    // Listen to search open state from bottom nav or header
    ref.listen<bool>(homeSearchOpenProvider, (previous, next) {
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _searchFocusNode.requestFocus();
          }
        });
      } else {
        _searchFocusNode.unfocus();
      }
    });

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 6
        : (width > 900 ? 4 : (width > 600 ? 3 : 2));

    final matchingLabels = PersonaLabelService.getMatchingLabels(_searchController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSearchOpen ? 'Search Personas' : 'Persona'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(isSearchOpen ? Icons.search_off_rounded : Icons.search_rounded),
            tooltip: isSearchOpen ? 'Close Search' : 'Search Personas',
            onPressed: isSearchOpen ? _closeSearch : _openSearch,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref.read(trendingEntitiesProvider.notifier).forceRefresh();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded),
            tooltip: 'Favorites',
            onPressed: () => context.push('/favorites'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Box & Dynamic Labels Section
          if (isSearchOpen) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF262626),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search personas, professions, countries...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70, size: 22),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white70, size: 18),
                          tooltip: 'Clear input',
                          onPressed: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                            setState(() {});
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                        tooltip: 'Close search',
                        onPressed: _closeSearch,
                      ),
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (val) {
                  ref.read(searchQueryProvider.notifier).state = val;
                },
              ),
            ),

            // Labels directly under the search box (updated in real-time as user types)
            if (matchingLabels.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: matchingLabels.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final label = matchingLabels[index];
                      return PersonaLabelChip(
                        label: label,
                        index: index,
                        onTap: () {
                          _searchController.text = label;
                          ref.read(searchQueryProvider.notifier).state = label;
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
              ),
          ],

          // Masonry Grid View: Search Results or Trending Infinite Feed
          Expanded(
            child: (isSearchOpen && searchQuery.isNotEmpty)
                ? _buildSearchResults(
                    ref.watch(searchResultsProvider),
                    favorites,
                    crossAxisCount,
                  )
                : _buildTrendingFeed(
                    entitiesAsyncValue,
                    favorites,
                    isLoadingMore,
                    crossAxisCount,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    AsyncValue<List<KnowledgeEntity>> searchResultsAsync,
    List<KnowledgeEntity> favorites,
    int crossAxisCount,
  ) {
    return searchResultsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(
                'Search failed: $err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.refresh(searchResultsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off_rounded, size: 56, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No personas found for "${_searchController.text}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try another keyword or tap one of the labels above',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return AnimationLimiter(
          child: MasonryGridView.count(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(12),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final entity = results[index];
              final isFavorite = favorites.any((e) => e.id == entity.id);

              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: const Duration(milliseconds: 300),
                columnCount: crossAxisCount,
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: EntityCard(
                      entity: entity,
                      isFavorite: isFavorite,
                      onToggleFavorite: () {
                        ref.read(favoritesProvider.notifier).toggleFavorite(entity);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTrendingFeed(
    AsyncValue<List<KnowledgeEntity>> entitiesAsyncValue,
    List<KnowledgeEntity> favorites,
    bool isLoadingMore,
    int crossAxisCount,
  ) {
    return entitiesAsyncValue.when(
      data: (entities) {
        if (entities.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(trendingEntitiesProvider.notifier).forceRefresh();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height - 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No personas found',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text('Pull down or tap refresh to reload'),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.read(trendingEntitiesProvider.notifier).forceRefresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await ref.read(trendingEntitiesProvider.notifier).forceRefresh();
          },
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (scrollInfo is ScrollUpdateNotification) {
                if (scrollInfo.metrics.maxScrollExtent > 0 &&
                    scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 400) {
                  final notifier = ref.read(trendingEntitiesProvider.notifier);
                  if (!notifier.isLoadingMore) {
                    notifier.loadMore();
                  }
                }
              }
              return false;
            },
            child: AnimationLimiter(
              child: MasonryGridView.count(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemCount: entities.length + (isLoadingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == entities.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.0),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final entity = entities[index];
                  final isFavorite = favorites.any((e) => e.id == entity.id);

                  return AnimationConfiguration.staggeredGrid(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    columnCount: crossAxisCount,
                    child: ScaleAnimation(
                      child: FadeInAnimation(
                        child: EntityCard(
                          entity: entity,
                          isFavorite: isFavorite,
                          onToggleFavorite: () {
                            ref.read(favoritesProvider.notifier).toggleFavorite(entity);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (error, stack) {
        final isNoInternet = error.toString().contains('SocketException');
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isNoInternet ? Icons.wifi_off_rounded : Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  isNoInternet
                      ? 'No Internet Connection. Please check your network and try again.'
                      : 'Error: $error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.read(trendingEntitiesProvider.notifier).forceRefresh(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
