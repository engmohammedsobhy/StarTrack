import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:itiproject/core/constants.dart';
import 'package:itiproject/core/widgets/shimmer_loading.dart';
import 'package:itiproject/features/favorites/presentation/providers/favorites_provider.dart';
import '../providers/person_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personsAsyncValue = ref.watch(popularPersonsProvider);
    final favorites = ref.watch(favoritesProvider);

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 6
        : (width > 900 ? 4 : (width > 600 ? 3 : 2));

    return Scaffold(
      appBar: AppBar(
        title: const Text('StarTrack'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () => context.push('/favorites'),
          ),
        ],
      ),
      body: personsAsyncValue.when(
        data: (persons) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(popularPersonsProvider);
            try {
              await ref.read(popularPersonsProvider.future);
            } catch (_) {}
          },
          child: AnimationLimiter(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.7,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final person = persons[index];
                      final isFavorite = favorites.any(
                        (e) => e.id == person.id,
                      );

                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        columnCount: crossAxisCount,
                        child: ScaleAnimation(
                          child: FadeInAnimation(
                            child: _PersonCard(
                              person: person,
                              isFavorite: isFavorite,
                              onToggleFavorite: () {
                                ref
                                    .read(favoritesProvider.notifier)
                                    .toggleFavorite(person);
                              },
                            ),
                          ),
                        ),
                      );
                    }, childCount: persons.length),
                  ),
                ),
              ],
            ),
          ),
        ),
        loading: () => _buildShimmerGrid(context),
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
                    onPressed: () => ref.invalidate(popularPersonsProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/chat'),
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('AI Assistant'),
      ),
    );
  }

  Widget _buildShimmerGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 6
        : (width > 900 ? 4 : (width > 600 ? 3 : 2));

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) =>
          const ShimmerLoading.rounded(height: double.infinity),
    );
  }
}

class _PersonCard extends StatelessWidget {
  final dynamic person;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _PersonCard({
    required this.person,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/person/${person.id}'),
        child: Stack(
          children: [
            Positioned.fill(
              child: Hero(
                tag: 'person_${person.id}',
                child: person.profilePath != null
                    ? CachedNetworkImage(
                        imageUrl:
                            '${AppConstants.imageBaseUrl}${person.profilePath}',
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const ShimmerLoading.rectangular(
                              height: double.infinity,
                            ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.person, size: 50),
                      )
                    : Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.person,
                          size: 80,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.0, 0.6, 0.8, 1.0],
                  ),
                ),
              ),
            ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Text(
                person.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: IconButton.filledTonal(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    size: 18,
                  ),
                  onPressed: onToggleFavorite,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
