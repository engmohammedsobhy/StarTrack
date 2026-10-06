import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../home/data/models/entity_model.dart';
import '../../data/models/persona_collection.dart';
import '../providers/collections_provider.dart';
import '../providers/favorites_provider.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  int _selectedTab = 0; // 0: All Saved, 1: Collections

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesProvider);
    final collectionsAsync = ref.watch(collectionsProvider);

    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 1200
        ? 6
        : (width > 900 ? 4 : (width > 600 ? 3 : 2));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved & Collections'),
        centerTitle: false,
        actions: [
          if (_selectedTab == 1)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'New Collection',
              onPressed: () => _showCreateCollectionDialog(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Control (All Saved vs Collections)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('All Saved'),
                    icon: Icon(Icons.bookmark_rounded),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Collections'),
                    icon: Icon(Icons.collections_bookmark_rounded),
                  ),
                ],
                selected: {_selectedTab},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedTab = newSelection.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Colors.redAccent,
                  selectedForegroundColor: Colors.white,
                  backgroundColor: const Color(0xFF1E1E1E),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
            ),
          ),

          // Main View Content
          Expanded(
            child: _selectedTab == 0
                ? (favorites.isEmpty
                    ? _buildEmptySavedState(context)
                    : MasonryGridView.count(
                        padding: const EdgeInsets.all(12),
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final entity = favorites[index];
                          return _buildFavoriteCard(context, ref, entity);
                        },
                      ))
                : collectionsAsync.when(
                    data: (collections) {
                      if (collections.isEmpty) {
                        return _buildEmptyCollectionsState(context);
                      }

                      final boardCrossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: boardCrossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: collections.length,
                        itemBuilder: (context, index) {
                          final collection = collections[index];
                          return _CollectionBoardCard(
                            collection: collection,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CollectionDetailScreen(
                                    collectionId: collection.id,
                                  ),
                                ),
                              );
                            },
                            onRename: () => _showRenameCollectionDialog(
                              context,
                              ref,
                              collection,
                            ),
                            onDelete: () => _showDeleteCollectionDialog(
                              context,
                              ref,
                              collection,
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    error: (err, stack) => Center(
                      child: Text(
                        'Error loading collections: $err',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteCard(
    BuildContext context,
    WidgetRef ref,
    KnowledgeEntity entity,
  ) {
    return GestureDetector(
      onTap: () => context.push(
        '/person/${Uri.encodeComponent(entity.title)}',
        extra: entity,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Hero(
              tag: 'entity_${entity.id}',
              child: AspectRatio(
                aspectRatio: entity.displayAspectRatio,
                child: (entity.thumbnailUrl != null &&
                        entity.thumbnailUrl!.trim().isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: entity.thumbnailUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        httpHeaders: const {
                          'User-Agent':
                              'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
                        },
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF1E1E1E),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF1E1E1E),
                          child: const Icon(Icons.person_outline,
                              color: Colors.grey, size: 40),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1E1E1E),
                        child: const Icon(
                          Icons.person_outline,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entity.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () {
                    ref
                        .read(favoritesProvider.notifier)
                        .toggleFavorite(entity);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.favorite, color: Colors.red, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildEmptySavedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.bookmark_border_rounded,
                size: 60,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Personas Yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save personas you find interesting to view them here anytime.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.explore),
              label: const Text('Explore Feed'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCollectionsState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.collections_bookmark_outlined,
              size: 70,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            const Text(
              'No Collections Created',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Organize your saved personas into custom Pinterest-style boards.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showCreateCollectionDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Create Collection'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCollectionDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF262626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('New Collection Board', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Collection Name (e.g. Scientists)',
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  await ref
                      .read(collectionsProvider.notifier)
                      .createCollection(name);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  void _showRenameCollectionDialog(
    BuildContext context,
    WidgetRef ref,
    PersonaCollection collection,
  ) {
    final controller = TextEditingController(text: collection.name);
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF262626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Rename Collection', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'New Collection Name',
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: const Color(0xFF1E1E1E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                final newName = controller.text.trim();
                if (newName.isNotEmpty) {
                  await ref
                      .read(collectionsProvider.notifier)
                      .renameCollection(collection.id, newName);
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteCollectionDialog(
    BuildContext context,
    WidgetRef ref,
    PersonaCollection collection,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF262626),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Delete "${collection.name}"?', style: const TextStyle(color: Colors.white)),
          content: const Text(
            'Are you sure you want to delete this collection board? Saved personas will still remain in All Saved.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(collectionsProvider.notifier)
                    .deleteCollection(collection.id);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}

/// Pinterest-Style Collection Board Card
class _CollectionBoardCard extends StatelessWidget {
  final PersonaCollection collection;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _CollectionBoardCard({
    required this.collection,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final images = collection.entities
        .map((e) => e.thumbnailUrl)
        .where((url) => url != null && url.trim().isNotEmpty)
        .take(4)
        .toList();

    final isDefault = collection.id == 'all_saved';

    return GestureDetector(
      onTap: onTap,
      onLongPress: isDefault ? null : () => _showBoardContextMenu(context),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Board Cover Image Preview (Collage)
            Expanded(
              child: Container(
                color: const Color(0xFF2B2B2B),
                child: _buildCollagePreview(images),
              ),
            ),

            // Board Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${collection.entities.length} saved',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDefault)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                      color: const Color(0xFF2B2B2B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'rename') {
                          onRename();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text('Rename', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollagePreview(List<String?> images) {
    if (images.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.redAccent.withValues(alpha: 0.2),
              const Color(0xFF1E1E1E),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.collections_bookmark_outlined,
            color: Colors.grey,
            size: 40,
          ),
        ),
      );
    }

    if (images.length == 1) {
      return CachedNetworkImage(
        imageUrl: images.first!,
        fit: BoxFit.cover,
        httpHeaders: const {
          'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
        },
        errorWidget: (context, url, error) => const Icon(
          Icons.person_outline,
          color: Colors.grey,
        ),
      );
    }

    if (images.length == 2) {
      return Row(
        children: [
          Expanded(
            child: CachedNetworkImage(
              imageUrl: images[0]!,
              fit: BoxFit.cover,
              height: double.infinity,
              httpHeaders: const {
                'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
              },
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: CachedNetworkImage(
              imageUrl: images[1]!,
              fit: BoxFit.cover,
              height: double.infinity,
              httpHeaders: const {
                'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
              },
            ),
          ),
        ],
      );
    }

    // 3 or 4 items: 2x2 Grid Collage
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: images[0]!,
                  fit: BoxFit.cover,
                  height: double.infinity,
                  httpHeaders: const {
                    'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
                  },
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: images[1]!,
                  fit: BoxFit.cover,
                  height: double.infinity,
                  httpHeaders: const {
                    'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: CachedNetworkImage(
                  imageUrl: images[2]!,
                  fit: BoxFit.cover,
                  height: double.infinity,
                  httpHeaders: const {
                    'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
                  },
                ),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: images.length > 3
                    ? CachedNetworkImage(
                        imageUrl: images[3]!,
                        fit: BoxFit.cover,
                        height: double.infinity,
                        httpHeaders: const {
                          'User-Agent':
                              'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
                        },
                      )
                    : Container(color: const Color(0xFF222222)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showBoardContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF262626),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                collection.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Rename Collection', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onRename();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Delete Collection', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDelete();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

/// Collection Detail Screen
class CollectionDetailScreen extends ConsumerWidget {
  final String collectionId;

  const CollectionDetailScreen({
    super.key,
    required this.collectionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionsAsync = ref.watch(collectionsProvider);

    return collectionsAsync.when(
      data: (collections) {
        final collection = collections.firstWhere(
          (c) => c.id == collectionId,
          orElse: () => PersonaCollection(
            id: collectionId,
            name: 'Collection',
            createdAt: DateTime.now(),
          ),
        );

        final width = MediaQuery.of(context).size.width;
        final crossAxisCount = width > 1200
            ? 6
            : (width > 900 ? 4 : (width > 600 ? 3 : 2));

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(collection.name),
                Text(
                  '${collection.entities.length} personas',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
          body: collection.entities.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.collections_bookmark_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No personas in "${collection.name}" yet.',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Back to Collections'),
                      ),
                    ],
                  ),
                )
              : MasonryGridView.count(
                  padding: const EdgeInsets.all(12),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  itemCount: collection.entities.length,
                  itemBuilder: (context, index) {
                    final entity = collection.entities[index];
                    return _buildCollectionEntityCard(
                      context,
                      ref,
                      collection.id,
                      entity,
                    );
                  },
                ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Collection')),
        body: Center(child: Text('Error: $err', style: const TextStyle(color: Colors.grey))),
      ),
    );
  }

  Widget _buildCollectionEntityCard(
    BuildContext context,
    WidgetRef ref,
    String colId,
    KnowledgeEntity entity,
  ) {
    return GestureDetector(
      onTap: () => context.push(
        '/person/${Uri.encodeComponent(entity.title)}',
        extra: entity,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Hero(
              tag: 'entity_${entity.id}',
              child: AspectRatio(
                aspectRatio: entity.displayAspectRatio,
                child: (entity.thumbnailUrl != null &&
                        entity.thumbnailUrl!.trim().isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: entity.thumbnailUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        httpHeaders: const {
                          'User-Agent':
                              'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
                        },
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF1E1E1E),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF1E1E1E),
                          child: const Icon(
                            Icons.person_outline,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1E1E1E),
                        child: const Icon(
                          Icons.person_outline,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entity.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.grey,
                    size: 20,
                  ),
                  tooltip: 'Remove from collection',
                  onPressed: () async {
                    await ref
                        .read(collectionsProvider.notifier)
                        .removeEntityFromCollection(colId, entity.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed ${entity.title}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
