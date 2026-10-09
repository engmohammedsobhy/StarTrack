import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:itiproject/core/widgets/persona_label_chip.dart';
import 'package:itiproject/core/widgets/shimmer_loading.dart';
import 'package:itiproject/core/widgets/entity_card.dart';

import 'package:itiproject/features/favorites/presentation/providers/favorites_provider.dart';
import 'package:itiproject/features/favorites/presentation/widgets/save_to_collection_sheet.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';
import 'package:itiproject/features/home/presentation/providers/user_interests_provider.dart';
import 'package:itiproject/features/search/presentation/providers/search_provider.dart';
import '../providers/person_details_provider.dart';
import '../widgets/persona_overview_cards_deck.dart';

class PersonDetailsScreen extends ConsumerStatefulWidget {
  final KnowledgeEntity entity;

  const PersonDetailsScreen({super.key, required this.entity});

  @override
  ConsumerState<PersonDetailsScreen> createState() =>
      _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends ConsumerState<PersonDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userInterestsProvider.notifier).recordViewedPersona(widget.entity);
    });
  }
  Future<void> _downloadImage(BuildContext context, String imageUrl) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final photosStatus = await Permission.photos.request();
          if (!photosStatus.isGranted) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Storage permission denied')),
              );
            }
            return;
          }
        }
      }

      final dio = Dio();
      Directory? directory;

      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        directory = await getDownloadsDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not access storage directory')),
          );
        }
        return;
      }

      String fileName = imageUrl.split('/').last;
      String savePath = '${directory.path}${Platform.pathSeparator}$fileName';

      await dio.download(
        imageUrl,
        savePath,
        options: Options(
          headers: {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
        ),
      );

      if (context.mounted) {
        String successMessage = Platform.isWindows
            ? 'Success! Image saved to your Downloads folder.'
            : 'Image downloaded to $savePath';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successMessage,
              style: const TextStyle(color: Colors.black),
            ),
            backgroundColor: Colors.white,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to download image: $e')));
      }
    }
  }

  void _showImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black87,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: () {
                _downloadImage(context, imageUrl);
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
          leading: const SizedBox.shrink(),
          leadingWidth: 0,
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              httpHeaders: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
              placeholder: (context, url) => Container(
                color: Colors.grey[900],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan)),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[900],
                child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ragOverviewAsync = ref.watch(ragOverviewProvider(widget.entity.title));
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.any((e) => e.id == widget.entity.id);

    final String? entityThumbnail = widget.entity.thumbnailUrl;
    final bool hasEntityThumbnail =
        entityThumbnail != null && entityThumbnail.trim().isNotEmpty;

    final String? effectiveHeaderImage = hasEntityThumbnail
        ? entityThumbnail
        : ragOverviewAsync.maybeWhen(
            data: (response) {
              if (response.imageUrls.isNotEmpty &&
                  response.imageUrls.first.trim().isNotEmpty) {
                return response.imageUrls.first;
              }
              return null;
            },
            orElse: () => null,
          );

    final List<String> displayedLabels = ragOverviewAsync.maybeWhen(
      data: (response) => response.labels.isNotEmpty
          ? response.labels
          : widget.entity.effectiveLabels,
      orElse: () => widget.entity.effectiveLabels,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            child: const BackButton(color: Colors.white),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/person_chat', extra: widget.entity);
        },
        backgroundColor: Colors.red,
        icon: const Icon(Icons.auto_awesome, color: Colors.white),
        label: const Text('Ask AI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo is ScrollUpdateNotification) {
            if (scrollInfo.metrics.maxScrollExtent > 0 && 
                scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
              ref.read(entityRecommendationsNotifierProvider(widget.entity.title).notifier).fetchMore();
            }
          }
          return false;
        },
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Hero(
                tag: 'entity_${widget.entity.id}',
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(40),
                  ),
                  child: (effectiveHeaderImage != null &&
                          effectiveHeaderImage.trim().isNotEmpty)
                      ? Container(
                          color: Colors.white,
                          child: CachedNetworkImage(
                            imageUrl: effectiveHeaderImage,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            httpHeaders: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
                            height: MediaQuery.of(context).size.height * 0.55,
                            width: double.infinity,
                            placeholder: (context, url) =>
                                const ShimmerLoading.rectangular(
                                  height: double.infinity,
                                ),
                            errorWidget: (context, url, error) {
                              final fallbackUrl = ragOverviewAsync.maybeWhen(
                                data: (resp) => resp.imageUrls.firstWhere(
                                  (img) => img != url && img.trim().isNotEmpty,
                                  orElse: () => '',
                                ),
                                orElse: () => '',
                              );
                              if (fallbackUrl.isNotEmpty) {
                                return CachedNetworkImage(
                                  imageUrl: fallbackUrl,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  httpHeaders: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
                                  height: MediaQuery.of(context).size.height * 0.55,
                                  width: double.infinity,
                                  errorWidget: (c, u, e) => Container(
                                    height: MediaQuery.of(context).size.height * 0.55,
                                    width: double.infinity,
                                    color: const Color(0xFF1E1E1E),
                                    child: const Center(
                                      child: Icon(Icons.person_outline, size: 100, color: Colors.grey),
                                    ),
                                  ),
                                );
                              }
                              return Container(
                                height: MediaQuery.of(context).size.height * 0.55,
                                width: double.infinity,
                                color: const Color(0xFF1E1E1E),
                                child: const Center(
                                  child: Icon(Icons.person_outline, size: 100, color: Colors.grey),
                                ),
                              );
                            },
                          ),
                        )
                      : Container(
                          height: MediaQuery.of(context).size.height * 0.55,
                          width: double.infinity,
                          color: const Color(0xFF1E1E1E),
                          child: const Center(
                            child: Icon(Icons.person_outline, size: 100, color: Colors.grey),
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  children: [
                    Text(
                      widget.entity.title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    if (displayedLabels.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      PersonaLabelsRow(
                        labels: displayedLabels,
                        scrollable: true,
                        onLabelTap: (label) {
                          ref.read(selectedSearchLabelsProvider.notifier).state = [label];
                          ref.read(selectedSearchLabelProvider.notifier).state = label;
                          ref.read(searchQueryProvider.notifier).state = '';
                          ref.read(userInterestsProvider.notifier).addSearch(label);
                          ref.read(homeSearchOpenProvider.notifier).state = true;
                          context.go('/');
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 160,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
                          showSaveToCollectionSheet(context, widget.entity);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: isFavorite
                              ? const Color(0xFF333333)
                              : Colors.white,
                          foregroundColor: isFavorite ? Colors.white : Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          isFavorite ? 'Saved' : 'Save',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer(
                      builder: (context, ref, child) {
                        final ragOverviewAsync = ref.watch(ragOverviewProvider(widget.entity.title));

                        return ragOverviewAsync.when(
                          data: (response) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Multi-card Swipeable Overview Deck
                                PersonaOverviewCardsDeck(
                                  cards: response.overviewCards,
                                  entity: widget.entity,
                                ),
                                const SizedBox(height: 24),

                                // Gallery Section
                                Text(
                                  'Gallery',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (response.imageUrls.isEmpty) ...[
                                  const Text('No gallery images available.', style: TextStyle(color: Colors.white54)),
                                  const SizedBox(height: 24),
                                ] else ...[
                                  SizedBox(
                                    height: 220,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: response.imageUrls.length,
                                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final imageUrl = response.imageUrls[index];
                                        return GestureDetector(
                                          onTap: () {
                                            _showImageDialog(context, imageUrl);
                                          },
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: CachedNetworkImage(
                                              imageUrl: imageUrl,
                                              height: 220,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter,
                                              httpHeaders: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
                                              placeholder: (context, url) => Container(
                                                height: 220,
                                                width: 150,
                                                color: Colors.grey[900],
                                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan)),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                height: 220,
                                                width: 150,
                                                color: Colors.grey[900],
                                                child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ],
                            );
                          },
                          loading: () => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: const [
                                    ShimmerLoading.rounded(height: 24, width: 120),
                                    ShimmerLoading.rounded(height: 22, width: 55),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: const ShimmerLoading.rectangular(
                                    height: 195,
                                    width: double.infinity,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Center(
                                  child: ShimmerLoading.rounded(height: 5, width: 60),
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'Gallery',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 220,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: 3,
                                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                                    itemBuilder: (context, index) => const ShimmerLoading.rounded(height: 220, width: 150),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          error: (e, _) => Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Overview',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Colors.orangeAccent),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Could not load persona overview.',
                                          style: TextStyle(color: Colors.white70, fontSize: 14),
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => ref.refresh(ragOverviewProvider(widget.entity.title)),
                                        icon: const Icon(Icons.refresh, color: Colors.cyanAccent, size: 18),
                                        label: const Text('Retry', style: TextStyle(color: Colors.cyanAccent)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Gallery',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text('No gallery images available.', style: TextStyle(color: Colors.white54)),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Related People & Characters Section
                    Text(
                      'Related People & Characters',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, child) {
                        final recommendationsAsync = ref.watch(entityRecommendationsNotifierProvider(widget.entity.title));
                        return recommendationsAsync.when(
                          data: (entities) {
                            if (entities.isEmpty) {
                              return const Text('No recommendations available.', style: TextStyle(color: Colors.grey));
                            }
                            return MasonryGridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              itemCount: entities.length,
                              itemBuilder: (context, index) {
                                return EntityCard(
                                  entity: entities[index],
                                  isFavorite: favorites.any((e) => e.id == entities[index].id),
                                  onToggleFavorite: () {
                                    ref.read(favoritesProvider.notifier).toggleFavorite(entities[index]);
                                  },
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                          error: (e, _) => const Text('No recommendations available.', style: TextStyle(color: Colors.grey)),
                        );
                      },
                    ),
                    const SizedBox(height: 80), // Padding for FAB
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
