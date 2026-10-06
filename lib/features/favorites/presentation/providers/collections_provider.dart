import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/persona_collection.dart';
import '../../data/repositories/collection_repository.dart';
import '../../../home/data/models/entity_model.dart';
import 'favorites_provider.dart';

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository();
});

class CollectionsNotifier extends AsyncNotifier<List<PersonaCollection>> {
  @override
  Future<List<PersonaCollection>> build() async {
    final repository = ref.watch(collectionRepositoryProvider);
    final collections = await repository.getCollections();

    // Sync "All Saved" with favoritesProvider
    final favorites = ref.watch(favoritesProvider);
    return _syncAllSaved(collections, favorites);
  }

  List<PersonaCollection> _syncAllSaved(
    List<PersonaCollection> collections,
    List<KnowledgeEntity> favorites,
  ) {
    final index = collections.indexWhere((c) => c.id == 'all_saved');
    if (index != -1) {
      final updatedAllSaved = collections[index].copyWith(entities: favorites);
      final updatedList = List<PersonaCollection>.from(collections);
      updatedList[index] = updatedAllSaved;
      return updatedList;
    } else {
      final allSaved = PersonaCollection(
        id: 'all_saved',
        name: 'All Saved',
        createdAt: DateTime.now(),
        entities: favorites,
      );
      return [allSaved, ...collections];
    }
  }

  Future<void> createCollection(String name) async {
    final repository = ref.read(collectionRepositoryProvider);
    final newCollection = await repository.createCollection(name);
    final currentList = state.value ?? [];
    state = AsyncData([...currentList, newCollection]);
  }

  Future<void> renameCollection(String id, String newName) async {
    if (id == 'all_saved') return;
    final repository = ref.read(collectionRepositoryProvider);
    await repository.renameCollection(id, newName);
    
    final currentList = state.value ?? [];
    state = AsyncData(currentList.map((c) {
      if (c.id == id) {
        return c.copyWith(name: newName.trim().isEmpty ? c.name : newName.trim());
      }
      return c;
    }).toList());
  }

  Future<void> deleteCollection(String id) async {
    if (id == 'all_saved') return;
    final repository = ref.read(collectionRepositoryProvider);
    await repository.deleteCollection(id);

    final currentList = state.value ?? [];
    state = AsyncData(currentList.where((c) => c.id != id).toList());
  }

  /// Toggles an entity in a specific collection.
  /// Returns `true` if entity was added, `false` if removed.
  Future<bool> toggleEntityInCollection(String collectionId, KnowledgeEntity entity) async {
    final repository = ref.read(collectionRepositoryProvider);
    final collections = state.value ?? await repository.getCollections();

    final targetIndex = collections.indexWhere((c) => c.id == collectionId);
    if (targetIndex == -1) return false;

    final collection = collections[targetIndex];
    final isInside = collection.entities.any((e) => e.id == entity.id);

    if (isInside) {
      await repository.removeEntityFromCollection(collectionId, entity.id);
      if (collectionId == 'all_saved') {
        // Also toggle in favoritesProvider if removing from All Saved
        if (ref.read(favoritesProvider.notifier).isFavorite(entity.id)) {
          await ref.read(favoritesProvider.notifier).toggleFavorite(entity);
        }
      }
    } else {
      await repository.addEntityToCollection(collectionId, entity);
      // Ensure it is also in favoritesProvider / All Saved
      if (!ref.read(favoritesProvider.notifier).isFavorite(entity.id)) {
        await ref.read(favoritesProvider.notifier).toggleFavorite(entity);
      }
    }

    final updatedCollections = await repository.getCollections();
    final favorites = ref.read(favoritesProvider);
    state = AsyncData(_syncAllSaved(updatedCollections, favorites));

    return !isInside;
  }

  Future<void> addEntityToCollection(String collectionId, KnowledgeEntity entity) async {
    final repository = ref.read(collectionRepositoryProvider);
    await repository.addEntityToCollection(collectionId, entity);

    if (!ref.read(favoritesProvider.notifier).isFavorite(entity.id)) {
      await ref.read(favoritesProvider.notifier).toggleFavorite(entity);
    }

    final updatedCollections = await repository.getCollections();
    final favorites = ref.read(favoritesProvider);
    state = AsyncData(_syncAllSaved(updatedCollections, favorites));
  }

  Future<void> removeEntityFromCollection(String collectionId, String entityId) async {
    final repository = ref.read(collectionRepositoryProvider);
    await repository.removeEntityFromCollection(collectionId, entityId);

    if (collectionId == 'all_saved') {
      final entity = ref.read(favoritesProvider).firstWhere((e) => e.id == entityId, orElse: () => KnowledgeEntity(id: entityId, title: ''));
      if (entity.id.isNotEmpty && ref.read(favoritesProvider.notifier).isFavorite(entityId)) {
        await ref.read(favoritesProvider.notifier).toggleFavorite(entity);
      }
    }

    final updatedCollections = await repository.getCollections();
    final favorites = ref.read(favoritesProvider);
    state = AsyncData(_syncAllSaved(updatedCollections, favorites));
  }
}

final collectionsProvider = AsyncNotifierProvider<CollectionsNotifier, List<PersonaCollection>>(
  CollectionsNotifier.new,
);
