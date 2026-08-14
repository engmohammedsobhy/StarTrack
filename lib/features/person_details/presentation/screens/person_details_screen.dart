import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:itiproject/core/widgets/shimmer_loading.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import '../../../home/data/models/person_model.dart';
import 'package:itiproject/features/favorites/presentation/providers/favorites_provider.dart';
import '../../../../core/constants.dart';
import '../providers/person_details_provider.dart';

class PersonDetailsScreen extends ConsumerStatefulWidget {
  final int personId;

  const PersonDetailsScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailsScreen> createState() =>
      _PersonDetailsScreenState();
}

class _PersonDetailsScreenState extends ConsumerState<PersonDetailsScreen> {
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

      await dio.download(imageUrl, savePath);

      if (context.mounted) {
        String successMessage = Platform.isWindows
            ? 'Success! Image saved to your Downloads folder.'
            : 'Image downloaded to $savePath';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.red.shade800,
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

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(personDetailsProvider(widget.personId));
    final imagesAsync = ref.watch(personImagesProvider(widget.personId));
    final creditsAsync = ref.watch(personCreditsProvider(widget.personId));
    final favorites = ref.watch(favoritesProvider);
    final isFavorite = favorites.any((e) => e.id == widget.personId);

    return detailsAsync.when(
      data: (details) => Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 400.0,
              pinned: true,
              stretch: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  details.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'person_${details.id}',
                      child: details.profilePath != null
                          ? CachedNetworkImage(
                              imageUrl:
                                  '${AppConstants.imageBaseUrl}${details.profilePath}',
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  const ShimmerLoading.rectangular(
                                    height: double.infinity,
                                  ),
                            )
                          : Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black54],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
                  ),
                  onPressed: () {
                    ref
                        .read(favoritesProvider.notifier)
                        .toggleFavorite(
                          Person(
                            id: details.id,
                            name: details.name,
                            profilePath: details.profilePath,
                          ),
                        );
                  },
                ),
              ],
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle(context, 'Personal Details'),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              if (details.birthday != null)
                                _InfoRow(
                                  icon: Icons.cake_outlined,
                                  text: 'Born: ${details.birthday}',
                                ),
                              if (details.placeOfBirth != null)
                                _InfoRow(
                                  icon: Icons.location_on_outlined,
                                  text: details.placeOfBirth!,
                                ),
                              if (details.knownForDepartment != null)
                                _InfoRow(
                                  icon: Icons.work_outline,
                                  text:
                                      'Department: ${details.knownForDepartment!}',
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (details.biography != null &&
                          details.biography!.isNotEmpty) ...[
                        _buildSectionTitle(context, 'Biography'),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: MarkdownBody(
                              data: details.biography!,
                              styleSheet: MarkdownStyleSheet(
                                p: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(height: 1.6),
                                h1: Theme.of(context).textTheme.titleLarge,
                                h2: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      _buildSectionTitle(context, 'Top Work'),
                      const SizedBox(height: 12),
                      creditsAsync.when(
                        data: (credits) => credits.isEmpty
                            ? const Text('No data available')
                            : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: credits
                                    .map(
                                      (work) => Chip(
                                        label: Text(work),
                                        backgroundColor: Theme.of(context)
                                            .colorScheme
                                            .primaryContainer
                                            .withValues(alpha: 0.4),
                                        side: BorderSide.none,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Failed to load top work: $e'),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionTitle(context, 'Gallery'),
                      const SizedBox(height: 12),
                      imagesAsync.when(
                        data: (images) => images.isEmpty
                            ? const Text('No images available')
                            : SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: images.length,
                                  itemBuilder: (context, index) {
                                    final image = images[index];
                                    final imageUrl =
                                        '${AppConstants.imageBaseUrl}${image.filePath}';
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Stack(
                                          children: [
                                            InstaImageViewer(
                                              child: CachedNetworkImage(
                                                imageUrl: imageUrl,
                                                width: 140,
                                                height: 200,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const ShimmerLoading.rectangular(
                                                      height: 200,
                                                    ),
                                              ),
                                            ),
                                            Positioned(
                                              right: 4,
                                              bottom: 4,
                                              child: IconButton.filledTonal(
                                                icon: const Icon(
                                                  Icons.download,
                                                  size: 16,
                                                ),
                                                onPressed: () => _downloadImage(
                                                  context,
                                                  imageUrl,
                                                ),
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                padding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                        loading: () => SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 3,
                            itemBuilder: (context, index) => const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: ShimmerLoading.rounded(
                                width: 140,
                                height: 200,
                              ),
                            ),
                          ),
                        ),
                        error: (e, _) => Text('Failed to load images: $e'),
                      ),
                      const SizedBox(height: 40),

                      Center(
                        child: FilledButton.icon(
                          onPressed: () => _downloadImage(
                            context,
                            '${AppConstants.imageBaseUrl}${details.profilePath}',
                          ),
                          icon: const Icon(Icons.download),
                          label: const Text('Download Profile Image'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
