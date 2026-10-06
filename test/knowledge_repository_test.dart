import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:itiproject/features/home/data/models/persona_search_result.dart';
import 'package:itiproject/features/home/data/repositories/knowledge_repository.dart';

class MockAdapter implements HttpClientAdapter {
  final Map<String, dynamic> responseData;
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

  group('KnowledgeRepository Search Tests', () {
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
  });
}
