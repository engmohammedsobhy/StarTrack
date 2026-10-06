import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../home/data/models/entity_model.dart';
import '../providers/collections_provider.dart';

void showSaveToCollectionSheet(BuildContext context, KnowledgeEntity entity) {
  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (modalContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
        ),
        child: SaveToCollectionSheetContent(entity: entity),
      );
    },
  );
}

class SaveToCollectionSheetContent extends ConsumerStatefulWidget {
  final KnowledgeEntity entity;

  const SaveToCollectionSheetContent({
    super.key,
    required this.entity,
  });

  @override
  ConsumerState<SaveToCollectionSheetContent> createState() =>
      _SaveToCollectionSheetContentState();
}

class _SaveToCollectionSheetContentState
    extends ConsumerState<SaveToCollectionSheetContent> {
  bool _isCreating = false;
  late final TextEditingController _newCollectionController;

  @override
  void initState() {
    super.initState();
    _newCollectionController = TextEditingController();
  }

  @override
  void dispose() {
    _newCollectionController.dispose();
    super.dispose();
  }

  void _handleCreateCollection() async {
    final name = _newCollectionController.text.trim();
    if (name.isEmpty) return;

    final notifier = ref.read(collectionsProvider.notifier);
    await notifier.createCollection(name);

    final collections = ref.read(collectionsProvider).value ?? [];
    final created = collections.firstWhere((c) => c.name == name, orElse: () => collections.last);

    final wasAdded = await notifier.toggleEntityInCollection(created.id, widget.entity);

    if (mounted) {
      setState(() {
        _isCreating = false;
        _newCollectionController.clear();
      });

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasAdded
                ? 'Created "${created.name}" and saved ${widget.entity.title}!'
                : 'Created collection "${created.name}"',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectionsAsync = ref.watch(collectionsProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Entity Preview Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFF2C2C2C),
                    child: (widget.entity.thumbnailUrl != null &&
                            widget.entity.thumbnailUrl!.trim().isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: widget.entity.thumbnailUrl!,
                            fit: BoxFit.cover,
                            httpHeaders: const {
                              'User-Agent':
                                  'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
                            },
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person_outline,
                              color: Colors.grey,
                            ),
                          )
                        : const Icon(
                            Icons.person_outline,
                            color: Colors.grey,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save to Collection',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.entity.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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

          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white12),

          // Inline Create Collection Input OR Button
          if (_isCreating)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newCollectionController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Collection name...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFF2C2C2C),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _handleCreateCollection(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _handleCreateCollection,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Create'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () {
                      setState(() {
                        _isCreating = false;
                        _newCollectionController.clear();
                      });
                    },
                  ),
                ],
              ),
            )
          else
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFF2C2C2C),
                child: Icon(Icons.add, color: Colors.white),
              ),
              title: const Text(
                'Create New Collection',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              onTap: () {
                setState(() {
                  _isCreating = true;
                });
              },
            ),

          const Divider(height: 1, color: Colors.white12),

          // List of User Collections
          Flexible(
            child: collectionsAsync.when(
              data: (collections) {
                if (collections.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        'No collections found.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: collections.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final collection = collections[index];
                    final isSavedInCollection = collection.entities
                        .any((e) => e.id == widget.entity.id);

                    // Cover thumbnail
                    String? coverImage;
                    for (var e in collection.entities) {
                      if (e.thumbnailUrl != null &&
                          e.thumbnailUrl!.trim().isNotEmpty) {
                        coverImage = e.thumbnailUrl;
                        break;
                      }
                    }

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 44,
                          height: 44,
                          color: const Color(0xFF2C2C2C),
                          child: coverImage != null
                              ? CachedNetworkImage(
                                  imageUrl: coverImage,
                                  fit: BoxFit.cover,
                                  httpHeaders: const {
                                    'User-Agent':
                                        'StarTrackAI-Engine/2.3 (contact@startrack.ai)'
                                  },
                                  errorWidget: (context, url, error) => const Icon(
                                    Icons.collections_bookmark_outlined,
                                    color: Colors.grey,
                                  ),
                                )
                              : const Icon(
                                  Icons.collections_bookmark_outlined,
                                  color: Colors.grey,
                                ),
                        ),
                      ),
                      title: Text(
                        collection.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        '${collection.entities.length} saved personas',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                      trailing: isSavedInCollection
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.redAccent,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check,
                                    color: Colors.redAccent,
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Saved',
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : OutlinedButton(
                              onPressed: () async {
                                final wasAdded = await ref
                                    .read(collectionsProvider.notifier)
                                    .toggleEntityInCollection(
                                      collection.id,
                                      widget.entity,
                                    );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        wasAdded
                                            ? 'Saved ${widget.entity.title} to ${collection.name}'
                                            : 'Removed ${widget.entity.title} from ${collection.name}',
                                      ),
                                      duration: const Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: Colors.grey[700]!),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 6,
                                ),
                              ),
                              child: const Text('Save'),
                            ),
                      onTap: () async {
                        final wasAdded = await ref
                            .read(collectionsProvider.notifier)
                            .toggleEntityInCollection(
                              collection.id,
                              widget.entity,
                            );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                wasAdded
                                    ? 'Saved ${widget.entity.title} to ${collection.name}'
                                    : 'Removed ${widget.entity.title} from ${collection.name}',
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
              error: (err, stack) => Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'Error: $err',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
