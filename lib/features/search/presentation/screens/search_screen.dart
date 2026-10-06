import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:itiproject/core/widgets/entity_card.dart';
import 'package:itiproject/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';
import 'package:itiproject/features/search/presentation/providers/search_provider.dart';
import '../../../home/presentation/providers/entity_provider.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _searchController;
  late final PageController _bannerPageController;
  int _currentBannerIndex = 0;

  final List<Map<String, String>> _featuredIdeas = const [
    {
      'tag': 'IDEAS FOR YOU',
      'title': 'Iconic Innovators',
      'subtitle': 'Minds that shaped modern science & technology',
      'query': 'Albert Einstein',
      'image': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Einstein_1921_by_F_Schmutzer_-_restoration.jpg/600px-Einstein_1921_by_F_Schmutzer_-_restoration.jpg',
    },
    {
      'tag': 'HOLLYWOOD CLASSICS',
      'title': 'Cinema Legends',
      'subtitle': 'Timeless actors & visionary film directors',
      'query': 'Leonardo DiCaprio',
      'image': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/25/Leonardo_DiCap_Nov_08.jpg/600px-Leonardo_DiCap_Nov_08.jpg',
    },
    {
      'tag': 'HISTORICAL FIGURES',
      'title': 'World Leaders',
      'subtitle': 'Statesmen who altered the course of history',
      'query': 'Abraham Lincoln',
      'image': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Abraham_Lincoln_O-77_by_Gardner%2C_1863-crop.jpg/600px-Abraham_Lincoln_O-77_by_Gardner%2C_1863-crop.jpg',
    },
  ];

  final List<String> _filterChips = const [
    'All',
    'Actors',
    'Musicians',
    'Scientists',
    'Athletes',
    'Philosophers',
    'Historians',
  ];

  static const List<String> _hollywoodNames = [
    'Leonardo DiCaprio',
    'Marilyn Monroe',
    'Tom Cruise',
    'Audrey Hepburn',
  ];

  static const List<String> _leadersNames = [
    'Abraham Lincoln',
    'Winston Churchill',
    'Mahatma Gandhi',
    'Nelson Mandela',
  ];

  static const List<String> _scienceNames = [
    'Albert Einstein',
    'Marie Curie',
    'Isaac Newton',
    'Nikola Tesla',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: ref.read(searchQueryProvider));
    _bannerPageController = PageController(viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(searchQueryProvider);
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final selectedFilter = ref.watch(selectedFilterChipProvider);
    final trendingGridAsync = ref.watch(searchTrendingGridProvider);
    final favorites = ref.watch(favoritesProvider);

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 6
        : (width > 900 ? 4 : (width > 600 ? 3 : 2));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          children: [
            // Floating Pill-Shaped Top Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.search, color: Colors.grey, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Search Persona...',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 15),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                        onPressed: _clearSearch,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 20),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Visual Lens Camera coming soon!')),
                          );
                        },
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),

            // Main Content Area: Default Explore View vs Active Search Results
            Expanded(
              child: searchQuery.isNotEmpty
                  ? _buildSearchResults(searchResultsAsync, favorites, crossAxisCount)
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(trendingEntitiesProvider.notifier).forceRefresh();
                        ref.invalidate(searchTrendingGridProvider);
                        ref.invalidate(curatedCategorySectionProvider(_hollywoodNames));
                        ref.invalidate(curatedCategorySectionProvider(_leadersNames));
                        ref.invalidate(curatedCategorySectionProvider(_scienceNames));
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          const SizedBox(height: 12),

                          // 1. Featured Idea Banner Carousel
                          SizedBox(
                            height: 180,
                            child: PageView.builder(
                              controller: _bannerPageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentBannerIndex = index;
                                });
                              },
                              itemCount: _featuredIdeas.length,
                              itemBuilder: (context, index) {
                                final idea = _featuredIdeas[index];
                                return _buildHeroBannerCard(idea);
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _featuredIdeas.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: _currentBannerIndex == index ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _currentBannerIndex == index
                                      ? Colors.white
                                      : Colors.grey[700],
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 2. Curated Category Sections
                          _buildCategorySection('Hollywood Legends', _hollywoodNames),
                          const SizedBox(height: 20),
                          _buildCategorySection('World Leaders', _leadersNames),
                          const SizedBox(height: 20),
                          _buildCategorySection('Scientific Geniuses', _scienceNames),

                          const SizedBox(height: 28),

                          // 3. Popular Filter Chips
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: Colors.orangeAccent, size: 20),
                                const SizedBox(width: 6),
                                const Text(
                                  'Popular Topics',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filterChips.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final chip = _filterChips[index];
                                final isSelected = selectedFilter == chip;
                                return ChoiceChip(
                                  label: Text(chip),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      ref.read(selectedFilterChipProvider.notifier).state = chip;
                                    }
                                  },
                                  selectedColor: Colors.white,
                                  backgroundColor: const Color(0xFF262626),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected ? Colors.white : Colors.transparent,
                                    ),
                                  ),
                                  showCheckmark: false,
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 4. Trending Person Grid
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              selectedFilter == 'All' ? 'Trending Ideas' : '$selectedFilter Personas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          trendingGridAsync.when(
                            data: (entities) {
                              if (entities.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 32),
                                  child: Center(
                                    child: Text('No trending personas found.', style: TextStyle(color: Colors.grey)),
                                  ),
                                );
                              }
                              return MasonryGridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                crossAxisCount: crossAxisCount,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                itemCount: entities.length,
                                itemBuilder: (context, index) {
                                  final entity = entities[index];
                                  final isFavorite = favorites.any((e) => e.id == entity.id);
                                  return EntityCard(
                                    entity: entity,
                                    isFavorite: isFavorite,
                                    onToggleFavorite: () {
                                      ref.read(favoritesProvider.notifier).toggleFavorite(entity);
                                    },
                                  );
                                },
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(child: CircularProgressIndicator(color: Colors.white)),
                            ),
                            error: (err, stack) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              child: Center(
                                child: Text(
                                  'Error loading trending items: $err',
                                  style: const TextStyle(color: Colors.grey),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBannerCard(Map<String, String> idea) {
    return GestureDetector(
      onTap: () {
        _searchController.text = idea['query']!;
        ref.read(searchQueryProvider.notifier).state = idea['query']!;
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: idea['image']!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                httpHeaders: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
                placeholder: (context, url) => Container(color: const Color(0xFF262626)),
                errorWidget: (context, url, error) => Container(color: const Color(0xFF262626)),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      idea['tag']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    idea['title']!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    idea['subtitle']!,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(String sectionTitle, List<String> personNames) {
    final sectionAsync = ref.watch(curatedCategorySectionProvider(personNames));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$sectionTitle >',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () {
                  _searchController.text = sectionTitle.split(' ').first;
                  ref.read(searchQueryProvider.notifier).state = sectionTitle.split(' ').first;
                },
                child: const Text(
                  'See all',
                  style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: sectionAsync.when(
            data: (entities) {
              if (entities.isEmpty) {
                return const Center(child: Text('Loading category...', style: TextStyle(color: Colors.grey)));
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: entities.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final entity = entities[index];
                  return _buildCategoryPersonCard(entity);
                },
              );
            },
            loading: () => ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => Container(
                width: 110,
                decoration: BoxDecoration(
                  color: const Color(0xFF262626),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPersonCard(KnowledgeEntity entity) {
    return GestureDetector(
      onTap: () => context.push('/person/${Uri.encodeComponent(entity.title)}', extra: entity),
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1E1E1E),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: (entity.thumbnailUrl != null && entity.thumbnailUrl!.trim().isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: entity.thumbnailUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      httpHeaders: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
                      placeholder: (context, url) => Container(color: const Color(0xFF1E1E1E)),
                      errorWidget: (context, url, error) => Container(
                        color: const Color(0xFF1E1E1E),
                        child: const Icon(Icons.person_outline, color: Colors.grey),
                      ),
                    )
                  : Container(
                      color: const Color(0xFF1E1E1E),
                      child: const Icon(Icons.person_outline, color: Colors.grey),
                    ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                entity.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(
    AsyncValue<List<KnowledgeEntity>> searchResultsAsync,
    List<KnowledgeEntity> favorites,
    int crossAxisCount,
  ) {
    return searchResultsAsync.when(
      data: (entities) {
        if (entities.isEmpty) {
          return const Center(
            child: Text(
              'No personas found.',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return MasonryGridView.count(
          padding: const EdgeInsets.all(12),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: entities.length,
          itemBuilder: (context, index) {
            final entity = entities[index];
            final isFavorite = favorites.any((e) => e.id == entity.id);

            return EntityCard(
              entity: entity,
              isFavorite: isFavorite,
              onToggleFavorite: () {
                ref.read(favoritesProvider.notifier).toggleFavorite(entity);
              },
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
