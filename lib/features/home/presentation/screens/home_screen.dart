import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:itiproject/core/widgets/entity_card.dart';

import 'package:itiproject/features/favorites/presentation/providers/favorites_provider.dart';
import '../providers/entity_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final entitiesAsyncValue = ref.watch(trendingEntitiesProvider);
    final favorites = ref.watch(favoritesProvider);
    final isLoadingMore = ref.read(trendingEntitiesProvider.notifier).isLoadingMore;

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 6
        : (width > 900 ? 4 : (width > 600 ? 3 : 2));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Persona'), 
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            onPressed: () => context.push('/favorites'),
          ),
        ],
      ),
      body: entitiesAsyncValue.when(
        data: (entities) {
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
                              ref
                                  .read(favoritesProvider.notifier)
                                  .toggleFavorite(entity);
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
                    onPressed: () => ref.invalidate(trendingEntitiesProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
