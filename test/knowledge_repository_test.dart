import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:itiproject/features/home/data/models/persona_search_result.dart';
import 'package:itiproject/features/home/data/repositories/knowledge_repository.dart';

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

void main() {
  group('PersonaSearchResult Model Tests', () {
    test('PersonaSearchResult.fromJson parses model correctly with image_url', () {
      final json = {
        'title': 'Albert Einstein',
        'description': 'Theoretical physicist',
        'wikidata_id': 'Q937',
        'image_url': 'https://upload.wikimedia.org/einstein.jpg',
      };
      final result = PersonaSearchResult.fromJson(json);
      expect(result.title, 'Albert Einstein');
      expect(result.description, 'Theoretical physicist');
      expect(result.wikidataId, 'Q937');
      expect(result.imageUrl, 'https://upload.wikimedia.org/einstein.jpg');
    });
  });

  group('KnowledgeRepository Backend Endpoint Tests', () {
    test('searchEntities queries backend endpoint and converts PersonaSearchResult to KnowledgeEntity', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter({
        'results': [
          {
            'title': 'Lady Gaga',
            'description': 'American singer and actress',
            'wikidata_id': 'Q19848',
            'image_url': 'https://upload.wikimedia.org/lady_gaga.jpg',
          }
        ]
      });

      final repository = KnowledgeRepository(dio);
      final results = await repository.searchEntities('lady gaga');

      expect(results, isNotEmpty);
      expect(results.length, equals(1));
      final entity = results.first;
      expect(entity.id, equals('Q19848'));
      expect(entity.title, equals('Lady Gaga'));
      expect(entity.description, equals('American singer and actress'));
      expect(entity.thumbnailUrl, equals('https://upload.wikimedia.org/lady_gaga.jpg'));
    });

    test('getDiscoverPersonasViaBackend queries backend discover endpoint with pagination', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter([
        {
          'title': 'Buzz Aldrin',
          'description': 'American astronaut',
          'wikidata_id': 'Q2252',
          'image_url': 'https://upload.wikimedia.org/aldrin.jpg',
        },
        {
          'title': 'Neil Armstrong',
          'description': 'American astronaut',
          'wikidata_id': 'Q1615',
          'image_url': 'https://upload.wikimedia.org/armstrong.jpg',
        }
      ]);

      final repository = KnowledgeRepository(dio);
      final results = await repository.getDiscoverPersonasViaBackend(
        timestamp: 12345,
        page: 2,
        limit: 2,
      );

      expect(results.length, equals(2));
      expect(results[0].title, equals('Buzz Aldrin'));
      expect(results[1].title, equals('Neil Armstrong'));
    });

    test('getRagOverview queries POST /api/v1/rag/query and parses RagQueryResponse', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter({
        'entity': 'Albert Einstein',
        'answer': 'Albert Einstein was a German-born theoretical physicist.',
        'image_urls': ['https://upload.wikimedia.org/einstein1.jpg', 'https://upload.wikimedia.org/einstein2.jpg'],
        'retrieved_chunks': [
          {'chunk_id': 0, 'text': 'He won Nobel prize.', 'similarity_score': 0.85},
        ],
      });

      final repository = KnowledgeRepository(dio);
      final response = await repository.getRagOverview('Albert Einstein');

      expect(response.entity, equals('Albert Einstein'));
      expect(response.answer, contains('theoretical physicist'));
      expect(response.imageUrls.length, equals(2));
      expect(response.imageUrls.first, equals('https://upload.wikimedia.org/einstein1.jpg'));
      expect(response.overviewCards.length, greaterThanOrEqualTo(7));
      expect(response.overviewCards.first.title, contains('Albert Einstein'));
    });

    test('getRagOverview parses explicit 7+ overview_cards from backend JSON', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter({
        'entity': 'Marie Curie',
        'answer': 'Overview text',
        'image_urls': [],
        'retrieved_chunks': [],
        'overview_cards': [
          {'category': 'IDENTITY', 'subtitle': 'Core Essence', 'title': 'Who is Marie Curie?', 'content': 'Pioneering physicist', 'key_points': ['Radioactivity']},
          {'category': 'ORIGINS', 'subtitle': 'Formative Years', 'title': 'Early Years', 'content': 'Born in Warsaw', 'key_points': ['Poland']},
          {'category': 'CAREER', 'subtitle': 'Defining Works', 'title': 'Discoveries', 'content': 'Discovered Polonium & Radium', 'key_points': ['Elements']},
          {'category': 'SIGNATURE', 'subtitle': 'Method', 'title': 'Laboratory Rigor', 'content': 'Relentless experimentation', 'key_points': ['Research']},
          {'category': 'HONORS', 'subtitle': 'Historic Accolades', 'title': 'Two Nobel Prizes', 'content': 'First woman Nobel laureate', 'key_points': ['Physics', 'Chemistry']},
          {'category': 'LEGACY', 'subtitle': 'Lasting Footprint', 'title': 'Scientific Impact', 'content': 'Changed oncology & physics', 'key_points': ['Medicine']},
          {'category': 'TRIVIA', 'subtitle': 'Did You Know?', 'title': 'Curiosities', 'content': 'Notebooks still radioactive', 'key_points': ['Radioactive lore']},
        ]
      });

      final repository = KnowledgeRepository(dio);
      final response = await repository.getRagOverview('Marie Curie');

      expect(response.overviewCards.length, equals(7));
      expect(response.overviewCards[0].title, equals('Who is Marie Curie?'));
      expect(response.overviewCards[4].category, equals('HONORS'));
      expect(response.overviewCards[4].keyPoints, contains('Physics'));
    });

    test('getRecommendations queries POST /api/v1/personas/recommend and maps to KnowledgeEntity', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter({
        'recommendations': [
          {
            'title': 'Isaac Newton',
            'description': 'English mathematician and physicist',
            'wikidata_id': 'Q935',
            'image_url': 'https://upload.wikimedia.org/newton.jpg',
          }
        ]
      });

      final repository = KnowledgeRepository(dio);
      final results = await repository.getRecommendations(['Albert Einstein'], limit: 6);

      expect(results.length, equals(1));
      expect(results.first.title, equals('Isaac Newton'));
      expect(results.first.id, equals('Q935'));
    });

    test('getDiscoverPersonasViaBackend falls back to seed personas when backend fails', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter({}, statusCode: 500);

      final repository = KnowledgeRepository(dio);
      final results = await repository.getDiscoverPersonasViaBackend(
        timestamp: 9999,
        page: 1,
        limit: 6,
      );

      expect(results, isNotEmpty);
      expect(results.length, equals(6));
      expect(results.first.title, isNotEmpty);
      expect(results.first.thumbnailUrl, isNotNull);
    });

    test('searchEntities falls back when backend fails', () async {
      final dio = Dio();
      dio.httpClientAdapter = MockAdapter({}, statusCode: 500);

      final repository = KnowledgeRepository(dio);
      final results = await repository.searchEntities('Albert Einstein');

      expect(results, isNotEmpty);
      expect(results.first.title, contains('Albert Einstein'));
    });
  });
}

