import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itiproject/features/favorites/data/models/persona_collection.dart';
import 'package:itiproject/features/favorites/data/repositories/collection_repository.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PersonaCollection Model Tests', () {
    test('PersonaCollection parses from and serializes to JSON correctly', () {
      final now = DateTime.now();
      final collection = PersonaCollection(
        id: 'col_1',
        name: 'Scientists',
        createdAt: now,
        entities: [
          KnowledgeEntity(
            id: 'einstein',
            title: 'Albert Einstein',
            description: 'Physicist',
            thumbnailUrl: 'https://example.com/einstein.jpg',
          ),
        ],
      );

      final jsonMap = collection.toJson();
      final parsed = PersonaCollection.fromJson(jsonMap);

      expect(parsed.id, equals('col_1'));
      expect(parsed.name, equals('Scientists'));
      expect(parsed.entities.length, equals(1));
      expect(parsed.entities.first.title, equals('Albert Einstein'));
      expect(parsed.entityIds, contains('einstein'));
    });
  });

  group('CollectionRepository Tests', () {
    test('getCollections initializes default All Saved collection if empty', () async {
      final repository = CollectionRepository();
      final collections = await repository.getCollections();

      expect(collections, isNotEmpty);
      expect(collections.first.id, equals('all_saved'));
      expect(collections.first.name, equals('All Saved'));
    });

    test('createCollection adds new board and persists it', () async {
      final repository = CollectionRepository();
      final newCol = await repository.createCollection('Hollywood');

      final collections = await repository.getCollections();
      expect(collections.any((c) => c.name == 'Hollywood'), isTrue);
      expect(newCol.name, equals('Hollywood'));
    });

    test('addEntityToCollection and removeEntityFromCollection update collection', () async {
      final repository = CollectionRepository();
      final col = await repository.createCollection('Musicians');

      final entity = KnowledgeEntity(
        id: 'mozart',
        title: 'Wolfgang Amadeus Mozart',
      );

      await repository.addEntityToCollection(col.id, entity);
      var collections = await repository.getCollections();
      var updatedCol = collections.firstWhere((c) => c.id == col.id);
      expect(updatedCol.entities.any((e) => e.id == 'mozart'), isTrue);

      await repository.removeEntityFromCollection(col.id, 'mozart');
      collections = await repository.getCollections();
      updatedCol = collections.firstWhere((c) => c.id == col.id);
      expect(updatedCol.entities.any((e) => e.id == 'mozart'), isFalse);
    });

    test('renameCollection updates collection name', () async {
      final repository = CollectionRepository();
      final col = await repository.createCollection('Old Name');

      await repository.renameCollection(col.id, 'New Name');
      final collections = await repository.getCollections();
      final updatedCol = collections.firstWhere((c) => c.id == col.id);
      expect(updatedCol.name, equals('New Name'));
    });

    test('deleteCollection removes collection from list', () async {
      final repository = CollectionRepository();
      final col = await repository.createCollection('To Delete');

      await repository.deleteCollection(col.id);
      final collections = await repository.getCollections();
      expect(collections.any((c) => c.id == col.id), isFalse);
    });
  });
}
