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
  late final ScrollController _scrollController;      // trending feed
  late final ScrollController _searchScrollController; // search results
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _searchScrollController = ScrollController();
    _searchScrollController.addListener(_onSearchScroll);
    _searchController = TextEditingController(text: ref.read(searchQueryProvider));
    _searchFocusNode = FocusNode();
    _searchController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchScrollController.removeListener(_onSearchScroll);
    _searchScrollController.dispose();
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

  void _onSearchScroll() {
    if (_searchScrollController.hasClients) {
      final maxScroll = _searchScrollController.position.maxScrollExtent;
      final currentScroll = _searchScrollController.position.pixels;
      if (maxScroll > 0 && currentScroll >= maxScroll - 400) {
        ref.read(searchResultsNotifierProvider.notifier).loadMore();
      }
    }
  }

  void _openSearch() {
    ref.read(homeSearchOpenProvider.notifier).state = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    ref.read(homeSearchOpenProvider.notifier).state = false;
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedSearchLabelProvider.notifier).state = null;
    ref.read(selectedSearchLabelsProvider.notifier).state = [];
    _searchFocusNode.unfocus();
  }

  Widget _buildSearchBox(BuildContext context, List<String> selectedLabels) {
    final bool hasLabels = selectedLabels.isNotEmpty;

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: 14),
              const Icon(Icons.search_rounded, color: Colors.white70, size: 21),
              const SizedBox(width: 8),
              // Text field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14.5),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    hintText: hasLabels
                        ? 'Filter within label${selectedLabels.length > 1 ? 's' : ''}...'
                        : 'Search personas, professions...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) {
                    ref.read(searchQueryProvider.notifier).state = val;
                  },
                ),
              ),
              // One X to close entire search bar
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
                tooltip: 'Close Search',
                splashRadius: 20,
                onPressed: _closeSearch,
              ),
            ],
          ),
          // Stacked label chips inside the search box
          if (hasLabels)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: selectedLabels.asMap().entries.map((entry) {
                  final label = entry.value;
                  final color = PersonaLabelService.getLabelBackgroundColor(entry.key + 1, label);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: PersonaLabelService.labelTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 5),
                        GestureDetector(
                          onTap: () {
                            final current = List<String>.from(
                                ref.read(selectedSearchLabelsProvider));
                            current.remove(label);
                            ref.read(selectedSearchLabelsProvider.notifier).state = current;
                            // If last label was removed, also clear legacy
                            if (current.isEmpty) {
                              ref.read(selectedSearchLabelProvider.notifier).state = null;
                            }
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: PersonaLabelService.labelTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entitiesAsyncValue = ref.watch(trendingEntitiesProvider);
    final favorites = ref.watch(favoritesProvider);
    final isLoadingMore = ref.read(trendingEntitiesProvider.notifier).isLoadingMore;
    final isSearchOpen = ref.watch(homeSearchOpenProvider);
    final selectedLabels = ref.watch(selectedSearchLabelsProvider);
    final searchQuery = ref.watch(searchQueryProvider).trim();

    // Trigger paginated search whenever query or labels change
    ref.listen<String>(searchQueryProvider, (_, next) {
      ref.read(searchResultsNotifierProvider.notifier)
          .search(next, ref.read(selectedSearchLabelsProvider));
      if (_searchController.text != next) _searchController.text = next;
    });
    ref.listen<List<String>>(selectedSearchLabelsProvider, (_, next) {
      ref.read(searchResultsNotifierProvider.notifier)
          .search(ref.read(searchQueryProvider), next);
    });

    // Listen to search open state
    ref.listen<bool>(homeSearchOpenProvider, (previous, next) {
      if (next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchFocusNode.requestFocus();
        });
      } else {
        _searchFocusNode.unfocus();
      }
    });

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 6
        : (width > 900 ? 4 : (width > 600 ? 3 : 2));

    // Show all labels when a label is selected, else show matching for typed text
    // Exclude already-selected labels so they don't appear twice
    final matchingLabels = isSearchOpen
        ? PersonaLabelService.getMatchingLabels(
                selectedLabels.isNotEmpty ? '' : _searchController.text)
            .where((l) => !selectedLabels.contains(l))
            .toList()
        : <String>[];

    final bool showSearchResults =
        isSearchOpen && (searchQuery.isNotEmpty || selectedLabels.isNotEmpty);

    return Scaffold(
      appBar: isSearchOpen
          ? AppBar(
              automaticallyImplyLeading: false,
              titleSpacing: 12,
              // No action buttons on search AppBar
              title: _buildSearchBox(context, selectedLabels),
            )
          : AppBar(
              title: const Text('Persona'),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Search Personas',
                  onPressed: _openSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                  onPressed: () =>
                      ref.read(trendingEntitiesProvider.notifier).forceRefresh(),
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
          // Label chips row below AppBar when search is open
          if (isSearchOpen && matchingLabels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: matchingLabels.length,
                  separatorBuilder: (context, idx) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final label = matchingLabels[index];
                    final isSelected = selectedLabels.contains(label);
                    return PersonaLabelChip(
                      label: label,
                      index: isSelected ? 0 : index + 1,
                      onTap: () {
                        final current =
                            List<String>.from(ref.read(selectedSearchLabelsProvider));
                        if (isSelected) {
                          current.remove(label);
                        } else {
                          current.add(label);
                          // Clear text search when adding a label
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                        }
                        ref.read(selectedSearchLabelsProvider.notifier).state = current;
                        // Keep legacy single-label in sync (first label)
                        ref.read(selectedSearchLabelProvider.notifier).state =
                            current.isNotEmpty ? current.first : null;
                      },
                    );
                  },
                ),
              ),
            ),

          // Grid: Search Results or Trending Feed
          Expanded(
            child: showSearchResults
                ? _buildSearchResults(favorites, crossAxisCount)
                : _buildTrendingFeed(
                    entitiesAsyncValue, favorites, isLoadingMore, crossAxisCount),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(
    List<KnowledgeEntity> favorites,
    int crossAxisCount,
  ) {
    final searchState = ref.watch(searchResultsNotifierProvider);

    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (searchState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text('Search failed: ${searchState.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final q = ref.read(searchQueryProvider);
                  final lbs = ref.read(selectedSearchLabelsProvider);
                  ref.read(searchResultsNotifierProvider.notifier).search(q, lbs);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (searchState.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off_rounded, size: 56, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                ref.read(selectedSearchLabelsProvider).isNotEmpty
                    ? 'No personas found for selected labels'
                    : 'No personas found for "${_searchController.text}"',
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text('Try another keyword or tap a label above',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return AnimationLimiter(
      child: MasonryGridView.count(
        controller: _searchScrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(12),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: searchState.results.length + (searchState.isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= searchState.results.length) {
            // Loading more indicator
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: Colors.white54)),
            );
          }
          final entity = searchState.results[index];
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
                  onToggleFavorite: () =>
                      ref.read(favoritesProvider.notifier).toggleFavorite(entity),
                ),
              ),
            ),
          );
        },
      ),
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
