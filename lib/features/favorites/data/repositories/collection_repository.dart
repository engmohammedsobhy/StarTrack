import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/persona_collection.dart';
import '../../../home/data/models/entity_model.dart';

class CollectionRepository {
  static const String _key = 'persona_collections';

  Future<List<PersonaCollection>> getCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key);

    List<PersonaCollection> collections = [];
    if (jsonList != null && jsonList.isNotEmpty) {
      collections = jsonList
          .map((e) => PersonaCollection.fromJson(json.decode(e) as Map<String, dynamic>))
          .toList();
    }

    // Automatically initialize default collection ("All Saved") if missing
    final hasAllSaved = collections.any((c) => c.id == 'all_saved');
    if (!hasAllSaved) {
      final defaultCollection = PersonaCollection(
        id: 'all_saved',
        name: 'All Saved',
        createdAt: DateTime.now(),
        entities: const [],
      );
      collections.insert(0, defaultCollection);
      await saveCollections(collections);
    }

    return collections;
  }

  Future<void> saveCollections(List<PersonaCollection> collections) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = collections.map((c) => json.encode(c.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  Future<PersonaCollection> createCollection(String name) async {
    final collections = await getCollections();
    final newCollection = PersonaCollection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Untitled Board' : name.trim(),
      createdAt: DateTime.now(),
      entities: const [],
    );
    collections.add(newCollection);
    await saveCollections(collections);
    return newCollection;
  }

  Future<void> renameCollection(String id, String newName) async {
    if (id == 'all_saved') return; // Cannot rename default collection
    final collections = await getCollections();
    final index = collections.indexWhere((c) => c.id == id);
    if (index != -1) {
      collections[index] = collections[index].copyWith(
        name: newName.trim().isEmpty ? collections[index].name : newName.trim(),
      );
      await saveCollections(collections);
    }
  }

  Future<void> deleteCollection(String id) async {
    if (id == 'all_saved') return; // Cannot delete default collection
    final collections = await getCollections();
    collections.removeWhere((c) => c.id == id);
    await saveCollections(collections);
  }

  Future<void> addEntityToCollection(String collectionId, KnowledgeEntity entity) async {
    final collections = await getCollections();
    final index = collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      final currentEntities = List<KnowledgeEntity>.from(collections[index].entities);
      if (!currentEntities.any((e) => e.id == entity.id)) {
        currentEntities.add(entity);
        collections[index] = collections[index].copyWith(entities: currentEntities);
        await saveCollections(collections);
      }
    }
  }

  Future<void> removeEntityFromCollection(String collectionId, String entityId) async {
    final collections = await getCollections();
    final index = collections.indexWhere((c) => c.id == collectionId);
    if (index != -1) {
      final currentEntities = List<KnowledgeEntity>.from(collections[index].entities);
      currentEntities.removeWhere((e) => e.id == entityId);
      collections[index] = collections[index].copyWith(entities: currentEntities);
      await saveCollections(collections);
    }
  }
}
