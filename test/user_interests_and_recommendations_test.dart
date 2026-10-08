import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';
import 'package:itiproject/features/home/data/repositories/knowledge_repository.dart';
import 'package:itiproject/features/home/presentation/providers/user_interests_provider.dart';
import 'package:itiproject/features/favorites/presentation/providers/favorites_provider.dart';

class MockAdapter implements HttpClientAdapter {
  final dynamic responseData;
  final int statusCode;

  MockAdapter(this.responseData, {this.statusCode = 200});

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(responseData),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class FakeKnowledgeRepository extends KnowledgeRepository {
  FakeKnowledgeRepository() : super(Dio());

  @override
  Future<List<KnowledgeEntity>> getRecommendations(
    List<String> likedPersonas, {
    List<String> viewedPersonas = const [],
    List<String> searchedQueries = const [],
    int limit = 6,
  }) async {
    return [
      KnowledgeEntity(id: 'Q935', title: 'Isaac Newton', description: 'Physicist'),
      KnowledgeEntity(id: 'Q9036', title: 'Nikola Tesla', description: 'Inventor'),
    ];
  }

  @override
  Future<List<KnowledgeEntity>> searchEntities(String query) async {
    return [
      KnowledgeEntity(id: 'Q615', title: 'Lionel Messi', description: 'Footballer'),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserInterestsNotifier Tests', () {
    test('addSearch adds search query to top and deduplicates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userInterestsProvider.notifier);
      await notifier.addSearch('Lionel Messi');
      await notifier.addSearch('Albert Einstein');
      await notifier.addSearch('lionel messi'); // case insensitive match

      final state = container.read(userInterestsProvider);
      expect(state.recentSearches.length, 2);
      expect(state.recentSearches.first, 'lionel messi');
      expect(state.recentSearches[1], 'Albert Einstein');
    });

    test('removeSearch removes specific search query', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userInterestsProvider.notifier);
      await notifier.addSearch('Nikola Tesla');
      await notifier.addSearch('Marie Curie');

      await notifier.removeSearch('Nikola Tesla');

      final state = container.read(userInterestsProvider);
      expect(state.recentSearches, equals(['Marie Curie']));
    });

    test('clearSearches removes all search queries', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userInterestsProvider.notifier);
      await notifier.addSearch('Leonardo da Vinci');
      await notifier.clearSearches();

      final state = container.read(userInterestsProvider);
      expect(state.recentSearches, isEmpty);
    });

    test('recordViewedPersona tracks viewed personas without duplicates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(userInterestsProvider.notifier);
      final p1 = KnowledgeEntity(id: '1', title: 'Ada Lovelace');
      final p2 = KnowledgeEntity(id: '2', title: 'Alan Turing');
      final p1Again = KnowledgeEntity(id: '1', title: 'Ada Lovelace');

      await notifier.recordViewedPersona(p1);
      await notifier.recordViewedPersona(p2);
      await notifier.recordViewedPersona(p1Again);

      final state = container.read(userInterestsProvider);
      expect(state.viewedPersonas.length, 2);
      expect(state.viewedPersonas.first.title, 'Ada Lovelace');
      expect(state.viewedPersonas[1].title, 'Alan Turing');
    });
  });

  group('Multi-Signal Recommendations in KnowledgeRepository', () {
    test('getRecommendations accepts viewedPersonas and searchedQueries with mock adapter', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter({
        'recommendations': [
          {
            'title': 'Kylian Mbappe',
            'description': 'French footballer',
            'wikidata_id': 'Q27780014',
            'image_url': 'https://upload.wikimedia.org/mbappe.jpg',
          }
        ]
      });

      final repo = KnowledgeRepository(dio);
      final recs = await repo.getRecommendations(
        ['Lionel Messi'],
        viewedPersonas: ['Cristiano Ronaldo'],
        searchedQueries: ['football soccer'],
        limit: 4,
      );

      expect(recs.isNotEmpty, true);
      expect(recs.first.title, 'Kylian Mbappe');
      expect(recs.first.id, 'Q27780014');
    });
  });

  group('Dynamic Curated Sections Provider Tests', () {
    test('dynamicPersonalizedSectionsProvider provides sections for user with favorites', () async {
      final container = ProviderContainer(
        overrides: [
          knowledgeRepositoryProvider.overrideWithValue(FakeKnowledgeRepository()),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(
        dynamicPersonalizedSectionsProvider,
        (previous, next) {},
      );

      final favNotifier = container.read(favoritesProvider.notifier);
      await favNotifier.toggleFavorite(
        KnowledgeEntity(id: 'Q937', title: 'Albert Einstein', description: 'Physicist'),
      );

      final sections = await container.read(dynamicPersonalizedSectionsProvider.future);
      expect(sections.isNotEmpty, true);
      expect(sections.any((s) => s.title.contains('Albert Einstein') || s.title.contains('Because You Love')), true);
      expect(sections.first.entities.length, greaterThanOrEqualTo(1));
      sub.close();
    });
  });
}
