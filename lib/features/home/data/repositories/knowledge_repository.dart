import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/entity_model.dart';
import '../models/persona_search_result.dart';
import '../../../person_details/data/models/rag_response_model.dart';
import '../../../../core/services/persona_label_service.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return KnowledgeRepository(Dio());
});

class KnowledgeRepository {
  final Dio _dio;

  static const Map<String, String> _headers = {
    'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)',
  };

  final Map<String, List<KnowledgeEntity>> _searchCache = {};
  final Map<String, String> _bioCache = {};
  final Map<String, List<String>> _galleryCache = {};

  static const List<String> defaultPersonaPool = [
    'Tom Brady', 'Christian Bale', 'Augustus', 'Gal Gadot', 'Socrates',
    'Elizabeth II', 'Leonardo da Vinci', 'Pablo Picasso', 'Steven Spielberg',
    'Robert De Niro', 'Nelson Mandela', 'Cleopatra', 'Albert Einstein',
    'Marie Curie', 'Alexander the Great', 'Marilyn Monroe', 'Muhammad Ali',
    'Julius Caesar', 'Audrey Hepburn', 'Isaac Newton', 'Zendaya',
    'Winston Churchill', 'Cillian Murphy', 'Frida Kahlo', 'Bruce Lee', 'Lionel Messi',
    'Keanu Reeves', 'Scarlett Johansson', 'Nikola Tesla', 'Vincent van Gogh',
    'Martin Luther King Jr.', 'Mahatma Gandhi', 'Rosa Parks', 'Amelia Earhart',
    'William Shakespeare', 'Wolfgang Amadeus Mozart', 'Ludwig van Beethoven', 'Aristotle',
    'Plato', 'Joan of Arc', 'Genghis Khan', 'George Washington', 'Abraham Lincoln',
    'Thomas Edison', 'Henry Ford', 'Walt Disney', 'Charlie Chaplin', 'Elvis Presley',
    'Michael Jackson', 'Madonna', 'John Lennon', 'Paul McCartney', 'David Bowie',
    'Freddie Mercury', 'Queen Victoria', 'Charles Darwin', 'Stephen Hawking',
    'Alan Turing', 'Steve Jobs', 'Bill Gates', 'Mark Zuckerberg', 'Elon Musk',
    'Neil Armstrong', 'Buzz Aldrin', 'Yuri Gagarin', 'Jackie Robinson', 'Babe Ruth',
    'Michael Jordan', 'Serena Williams', 'Roger Federer', 'Cristiano Ronaldo',
    'Pele', 'Diego Maradona', 'Usain Bolt', 'Simone Biles', 'Malala Yousafzai',
    'Mother Teresa', 'Dalai Lama', 'Pope Francis', 'Kofi Annan', 'Margaret Thatcher',
    'Angela Merkel', 'Indira Gandhi', 'J.R.R. Tolkien', 'J.K. Rowling', 'Stephen King',
    'Agatha Christie', 'Ernest Hemingway', 'Mark Twain', 'Charles Dickens',
    'Jane Austen', 'Edgar Allan Poe', 'Virginia Woolf', 'Sylvia Plath', 'Maya Angelou',
  ];

  static List<KnowledgeEntity> get _initialSeedPersonas => [
    KnowledgeEntity(
      id: 'Q937',
      title: 'Albert Einstein',
      description: 'German-born theoretical physicist (1879–1955)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/2/28/Albert_Einstein_Head_cleaned.jpg/960px-Albert_Einstein_Head_cleaned.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Albert_Einstein',
    ),
    KnowledgeEntity(
      id: 'Q7186',
      title: 'Marie Curie',
      description: 'Polish-French physicist and chemist (1867–1934)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c8/Marie_Curie_c._1920s.jpg/960px-Marie_Curie_c._1920s.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Marie_Curie',
    ),
    KnowledgeEntity(
      id: 'Q762',
      title: 'Leonardo da Vinci',
      description: 'Italian polymath (1452–1519)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/1/16/Francesco_Melzi_-_Portrait_of_Leonardo_%28colour_correction%29.png/960px-Francesco_Melzi_-_Portrait_of_Leonardo_%28colour_correction%29.png?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Leonardo_da_Vinci',
    ),
    KnowledgeEntity(
      id: 'Q45785',
      title: 'Christian Bale',
      description: 'English actor (born 1974)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/0/0a/Christian_Bale-7837.jpg/960px-Christian_Bale-7837.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Christian_Bale',
    ),
    KnowledgeEntity(
      id: 'Q185064',
      title: 'Gal Gadot',
      description: 'Israeli actress (born 1985)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/3/38/Gal_Gadot_by_Gage_Skidmore_3.jpg/960px-Gal_Gadot_by_Gage_Skidmore_3.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Gal_Gadot',
    ),
    KnowledgeEntity(
      id: 'Q202674',
      title: 'Cillian Murphy',
      description: 'Irish actor (born 1976)',
      thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/e/ed/Cillian_Murphy_at_the_London_premier_of_Steve_in_September_2025_%28cropped%29.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail_unscaled',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Cillian_Murphy',
    ),
    KnowledgeEntity(
      id: 'Q935',
      title: 'Isaac Newton',
      description: 'English polymath (1642–1727)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/f/f7/Portrait_of_Sir_Isaac_Newton%2C_1689_%28brightened%29.jpg/960px-Portrait_of_Sir_Isaac_Newton%2C_1689_%28brightened%29.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Isaac_Newton',
    ),
    KnowledgeEntity(
      id: 'Q9036',
      title: 'Nikola Tesla',
      description: 'Serbian-American engineer and inventor (1856–1943)',
      thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/commons/7/79/Tesla_circa_1890.jpeg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail_unscaled',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Nikola_Tesla',
    ),
    KnowledgeEntity(
      id: 'Q19837',
      title: 'Steve Jobs',
      description: 'American businessman and investor (1955–2011)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/5/51/Steve_Jobs_Headshot_2010_%28cropped_4%29.jpg/960px-Steve_Jobs_Headshot_2010_%28cropped_4%29.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Steve_Jobs',
    ),
    KnowledgeEntity(
      id: 'Q615',
      title: 'Lionel Messi',
      description: 'Argentine footballer (born 1987)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c8/Leo_Messi_Argentina_v_Egypt_7_July_2026-1.jpg/960px-Leo_Messi_Argentina_v_Egypt_7_July_2026-1.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Lionel_Messi',
      labels: const ['Argentina', 'Football Player', 'Football Legend', 'World Cup Champion', 'FC Barcelona', 'Inter Miami'],
    ),
    KnowledgeEntity(
      id: 'Q36834',
      title: 'Tom Brady',
      description: 'American football player and commentator (born 1977)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/7/73/25th_Laureus_World_Sports_Awards_-_Red_Carpet_-_Tom_Brady_-_240422_191334_%28cropped%29_%28cropped%29.jpg/960px-25th_Laureus_World_Sports_Awards_-_Red_Carpet_-_Tom_Brady_-_240422_191334_%28cropped%29_%28cropped%29.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Tom_Brady',
      labels: const ['NFL Legend', 'Quarterback', '7x Super Bowl Champion', 'American Football'],
    ),
    KnowledgeEntity(
      id: 'Q36949',
      title: 'Robert De Niro',
      description: 'American actor (born 1943)',
      thumbnailUrl: 'https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c1/Robert_de_Niro_Cannes_Film_Festival_%283x4_cropped%29.jpg/960px-Robert_de_Niro_Cannes_Film_Festival_%283x4_cropped%29.jpg?utm_source=en.wikipedia.org&utm_campaign=api&utm_content=thumbnail',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Robert_De_Niro',
      labels: const ['Cinema Legend', 'Academy Award Winner', 'The Godfather', 'Hollywood Star'],
    ),
    KnowledgeEntity(
      id: 'Q217036',
      title: 'Sonic the Hedgehog',
      description: 'Iconic blue hedgehog video game character created by SEGA',
      thumbnailUrl: 'https://upload.wikimedia.org/wikipedia/en/a/a4/Sonic_the_Hedgehog_%28character%29.png',
      wikipediaUrl: 'https://en.wikipedia.org/wiki/Sonic_the_Hedgehog_(character)',
      labels: const ['Blue', 'Hedgehog', 'Video Game Character', 'Super Speed', 'SEGA Icon', 'Gaming Legend'],
    ),
  ];

  List<String> get _candidateBaseUrls {
    if (!kIsWeb && Platform.isAndroid) {
      return const ['http://10.0.2.2:8000', 'http://127.0.0.1:8000', 'http://localhost:8000'];
    }
    return const ['http://127.0.0.1:8000', 'http://localhost:8000', 'http://10.0.2.2:8000'];
  }

  KnowledgeRepository(this._dio);

  /// Discover Paginated Endpoint (`GET /api/v1/personas/discover`)
  Future<List<KnowledgeEntity>> getDiscoverPersonasViaBackend({
    required int timestamp,
    int page = 1,
    int limit = 6,
  }) async {
    List<dynamic>? rawList;
    final queryStr = '?page=$page&limit=$limit&ts=$timestamp';

    for (final baseUrl in _candidateBaseUrls) {
      try {
        final response = await _dio.get(
          '$baseUrl/api/v1/personas/discover$queryStr',
          options: Options(
            headers: _headers,
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );
        if (response.statusCode == 200 && response.data != null) {
          if (response.data is List) {
            rawList = response.data as List<dynamic>;
          } else if (response.data is Map && response.data['results'] is List) {
            rawList = response.data['results'] as List<dynamic>;
          } else if (response.data is Map && response.data['personas'] is List) {
            rawList = response.data['personas'] as List<dynamic>;
          }
          if (rawList != null && rawList.isNotEmpty) {
            break;
          }
        }
      } catch (_) {
        // Continue to next endpoint or fallback
      }
    }

    if (rawList != null && rawList.isNotEmpty) {
      final personaResults = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => PersonaSearchResult.fromJson(item))
          .toList();

      final parsed = personaResults.map((res) {
        final title = res.title.trim();
        return KnowledgeEntity(
          id: res.wikidataId.isNotEmpty ? res.wikidataId : title,
          title: title,
          description: res.description.trim(),
          thumbnailUrl: res.imageUrl,
          wikipediaUrl: res.wikidataId.isNotEmpty
              ? 'https://www.wikidata.org/wiki/${res.wikidataId}'
              : 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}',
        );
      }).where((entity) => entity.title.isNotEmpty).toList();

      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    // Robust client fallback: fetch discover personas directly from Wikipedia API
    return _fetchDiscoverPersonasDirect(
      timestamp: timestamp,
      page: page,
      limit: limit,
    );
  }

  Future<List<KnowledgeEntity>> _fetchDiscoverPersonasDirect({
    required int timestamp,
    int page = 1,
    int limit = 6,
  }) async {
    try {
      final pool = List<String>.from(defaultPersonaPool);
      final rng = math.Random(timestamp);
      for (int i = pool.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1);
        final temp = pool[i];
        pool[i] = pool[j];
        pool[j] = temp;
      }

      final pageNum = math.max(1, page);
      final requestedLimit = math.max(1, limit);
      final startIndex = (pageNum - 1) * requestedLimit;

      final List<String> candidateNames = [];
      for (int i = startIndex; i < startIndex + requestedLimit + 4; i++) {
        final name = pool[i % pool.length];
        if (!candidateNames.contains(name)) {
          candidateNames.add(name);
        }
        if (candidateNames.length >= requestedLimit) break;
      }

      if (candidateNames.isEmpty) {
        return _initialSeedPersonas.take(limit).toList();
      }

      final response = await _dio.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'titles': candidateNames.join('|'),
          'prop': 'pageimages|description|extracts',
          'exintro': '1',
          'explaintext': '1',
          'exsentences': '1',
          'piprop': 'thumbnail',
          'pithumbsize': '600',
          'format': 'json',
        },
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final pages = response.data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          final Map<String, KnowledgeEntity> fetchedMap = {};
          for (final page in pages.values) {
            final title = (page['title'] as String? ?? '').trim();
            if (title.isEmpty) continue;
            final desc = (page['description'] as String?)?.trim() ??
                (page['extract'] as String?)?.trim() ??
                'Notable figure';
            final thumb = page['thumbnail']?['source'] as String?;
            final pageId = (page['pageid'] ?? title).toString();

            fetchedMap[title.toLowerCase()] = KnowledgeEntity(
              id: pageId,
              title: title,
              description: desc,
              thumbnailUrl: thumb,
              wikipediaUrl: 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}',
            );
          }

          final List<KnowledgeEntity> results = [];
          for (final name in candidateNames) {
            final entity = fetchedMap[name.toLowerCase()];
            if (entity != null) {
              results.add(entity);
            }
          }
          if (results.isNotEmpty) {
            return results;
          }
        }
      }
    } catch (_) {}

    // Offline / Network fallback
    final seed = _initialSeedPersonas;
    final startIdx = ((page - 1) * limit) % seed.length;
    final List<KnowledgeEntity> fallback = [];
    for (int i = 0; i < limit; i++) {
      fallback.add(seed[(startIdx + i) % seed.length]);
    }
    return fallback;
  }

  /// Trending Entities using Discover Paginated Endpoint (`GET /api/v1/personas/discover`)
  Future<List<KnowledgeEntity>> getTrendingEntities({
    int page = 1,
    bool refresh = false,
    int? sessionTimestamp,
  }) async {
    final int ts = sessionTimestamp ?? DateTime.now().millisecondsSinceEpoch;
    return getDiscoverPersonasViaBackend(
      timestamp: ts,
      page: page,
      limit: 6,
    );
  }

  /// Search personas endpoint (`GET /api/v1/search/personas?q=...`)
  Future<List<KnowledgeEntity>> searchEntities(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];
    if (_searchCache.containsKey(cleanQuery)) return _searchCache[cleanQuery]!;

    final String encodedQuery = Uri.encodeComponent(cleanQuery);
    List<dynamic>? rawList;

    for (final baseUrl in _candidateBaseUrls) {
      try {
        final response = await _dio.get(
          '$baseUrl/api/v1/search/personas?q=$encodedQuery',
          options: Options(
            headers: _headers,
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );
        if (response.statusCode == 200 && response.data != null) {
          if (response.data is List) {
            rawList = response.data as List<dynamic>;
          } else if (response.data is Map && response.data['results'] is List) {
            rawList = response.data['results'] as List<dynamic>;
          } else if (response.data is Map && response.data['personas'] is List) {
            rawList = response.data['personas'] as List<dynamic>;
          }
          if (rawList != null && rawList.isNotEmpty) {
            break;
          }
        }
      } catch (_) {
        // Continue to next endpoint or fallback
      }
    }

    if (rawList != null && rawList.isNotEmpty) {
      final personaResults = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => PersonaSearchResult.fromJson(item))
          .toList();

      final List<KnowledgeEntity> entities = [];
      final Set<String> seenTitles = {};

      for (final res in personaResults) {
        if (res.title.trim().isEmpty) continue;
        final title = res.title.trim();
        if (seenTitles.contains(title.toLowerCase())) continue;

        final entity = KnowledgeEntity(
          id: res.wikidataId.isNotEmpty ? res.wikidataId : title,
          title: title,
          description: res.description.trim(),
          thumbnailUrl: res.imageUrl,
          wikipediaUrl: res.wikidataId.isNotEmpty
              ? 'https://www.wikidata.org/wiki/${res.wikidataId}'
              : 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}',
          labels: res.labels,
        );

        entities.add(entity);
        seenTitles.add(title.toLowerCase());
      }

      // If searching for a label, ensure personas matching the label are prioritized at the top
      final labelPersonaNames = PersonaLabelService.getPersonaNamesForLabel(cleanQuery);
      for (final pName in labelPersonaNames) {
        if (!seenTitles.contains(pName.toLowerCase())) {
          final seed = _initialSeedPersonas.firstWhere(
            (s) => s.title.toLowerCase() == pName.toLowerCase(),
            orElse: () => KnowledgeEntity(
              id: pName,
              title: pName,
              description: 'Notable Persona',
              wikipediaUrl: 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(pName)}',
              labels: PersonaLabelService.getLabelsForPersona(pName),
            ),
          );
          entities.insert(0, seed);
          seenTitles.add(pName.toLowerCase());
        }
      }

      for (final seed in _initialSeedPersonas) {
        if (!seenTitles.contains(seed.title.toLowerCase())) {
          final matchesLabel = seed.effectiveLabels.any((l) =>
              l.toLowerCase() == cleanQuery.toLowerCase() ||
              l.toLowerCase().contains(cleanQuery.toLowerCase()) ||
              cleanQuery.toLowerCase().contains(l.toLowerCase()));
          if (matchesLabel) {
            entities.insert(0, seed);
            seenTitles.add(seed.title.toLowerCase());
          }
        }
      }

      if (entities.isNotEmpty) {
        _searchCache[cleanQuery] = entities;
        return entities;
      }
    }

    // Robust client fallback: search directly via Wikipedia Search API
    return _searchEntitiesDirect(cleanQuery);
  }

  Future<List<KnowledgeEntity>> _searchEntitiesDirect(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    try {
      final response = await _dio.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'generator': 'search',
          'gsrsearch': cleanQuery,
          'gsrlimit': 15,
          'prop': 'pageimages|description|extracts',
          'exintro': '1',
          'explaintext': '1',
          'exsentences': '1',
          'piprop': 'thumbnail',
          'pithumbsize': '600',
          'format': 'json',
        },
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final pages = response.data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          final List<Map<String, dynamic>> sortedPages =
              pages.values.cast<Map<String, dynamic>>().toList();
          sortedPages.sort((a, b) => ((a['index'] ?? 999) as int).compareTo((b['index'] ?? 999) as int));

          final List<KnowledgeEntity> results = [];
          for (final page in sortedPages) {
            final title = (page['title'] as String? ?? '').trim();
            if (title.isEmpty) continue;
            final desc = (page['description'] as String?)?.trim() ??
                (page['extract'] as String?)?.trim() ??
                '';
            final lowerDesc = desc.toLowerCase();
            if (lowerDesc.contains('disambiguation') ||
                lowerDesc.contains('topics referred to') ||
                lowerDesc.contains('wikimedia list article')) {
              continue;
            }
            final thumb = page['thumbnail']?['source'] as String?;
            final pageId = (page['pageid'] ?? title).toString();

            results.add(KnowledgeEntity(
              id: pageId,
              title: title,
              description: desc.isNotEmpty ? desc : 'Notable persona',
              thumbnailUrl: thumb,
              wikipediaUrl: 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}',
            ));
          }

          // Prepend seed personas that match the query or its labels
          for (final seed in _initialSeedPersonas) {
            if (!results.any((r) => r.title.toLowerCase() == seed.title.toLowerCase())) {
              final matchesLabel = seed.effectiveLabels.any((l) =>
                  l.toLowerCase() == cleanQuery.toLowerCase() ||
                  l.toLowerCase().contains(cleanQuery.toLowerCase()) ||
                  cleanQuery.toLowerCase().contains(l.toLowerCase()));
              if (matchesLabel) {
                results.insert(0, seed);
              }
            }
          }

          if (results.isNotEmpty) {
            _searchCache[cleanQuery] = results;
            return results;
          }
        }
      }
    } catch (_) {}

    // Seed and label matching as fallback
    final labelSeedMatches = _initialSeedPersonas.where((e) {
      final matchesQuery = e.title.toLowerCase().contains(cleanQuery.toLowerCase());
      final matchesLabel = e.effectiveLabels.any((l) =>
          l.toLowerCase() == cleanQuery.toLowerCase() ||
          l.toLowerCase().contains(cleanQuery.toLowerCase()) ||
          cleanQuery.toLowerCase().contains(l.toLowerCase()));
      return matchesQuery || matchesLabel;
    }).toList();

    if (labelSeedMatches.isNotEmpty) {
      return labelSeedMatches;
    }

    return [];
  }

  /// Recommendations from Backend (`POST /api/v1/personas/recommend`)
  Future<List<KnowledgeEntity>> getRecommendations(
    List<String> likedPersonas, {
    List<String> viewedPersonas = const [],
    List<String> searchedQueries = const [],
    int limit = 6,
  }) async {
    List<dynamic>? rawList;

    final requestData = {
      "liked_personas": likedPersonas,
      "viewed_personas": viewedPersonas,
      "searched_queries": searchedQueries,
      "limit": limit,
    };

    for (final baseUrl in _candidateBaseUrls) {
      try {
        final response = await _dio.post(
          '$baseUrl/api/v1/personas/recommend',
          data: requestData,
          options: Options(
            headers: {
              ..._headers,
              'Content-Type': 'application/json',
            },
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 6),
          ),
        );
        if (response.statusCode == 200 && response.data != null) {
          if (response.data is List) {
            rawList = response.data as List<dynamic>;
          } else if (response.data is Map && response.data['results'] is List) {
            rawList = response.data['results'] as List<dynamic>;
          } else if (response.data is Map && response.data['personas'] is List) {
            rawList = response.data['personas'] as List<dynamic>;
          } else if (response.data is Map && response.data['recommendations'] is List) {
            rawList = response.data['recommendations'] as List<dynamic>;
          }
          if (rawList != null && rawList.isNotEmpty) {
            break;
          }
        }
      } catch (_) {
        // Continue to next endpoint or fallback
      }
    }

    if (rawList != null && rawList.isNotEmpty) {
      final personaResults = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => PersonaSearchResult.fromJson(item))
          .toList();

      final parsed = personaResults.map((res) {
        final title = res.title.trim();
        return KnowledgeEntity(
          id: res.wikidataId.isNotEmpty ? res.wikidataId : title,
          title: title,
          description: res.description.trim(),
          thumbnailUrl: res.imageUrl,
          wikipediaUrl: res.wikidataId.isNotEmpty
              ? 'https://www.wikidata.org/wiki/${res.wikidataId}'
              : 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}',
        );
      }).where((entity) => entity.title.isNotEmpty).toList();

      if (parsed.isNotEmpty) {
        return parsed;
      }
    }

    return _getRecommendationsDirect(
      likedPersonas,
      viewedPersonas: viewedPersonas,
      searchedQueries: searchedQueries,
      limit: limit,
    );
  }

  Future<List<KnowledgeEntity>> _getRecommendationsDirect(
    List<String> likedPersonas, {
    List<String> viewedPersonas = const [],
    List<String> searchedQueries = const [],
    int limit = 6,
  }) async {
    final seenLower = {...likedPersonas, ...viewedPersonas}
        .map((e) => e.toLowerCase().trim())
        .toSet();
    final remainingPool = defaultPersonaPool
        .where((name) => !seenLower.contains(name.toLowerCase()))
        .toList();

    final candidateNames = remainingPool.take(limit).toList();
    if (candidateNames.isEmpty) return _initialSeedPersonas.take(limit).toList();

    try {
      final response = await _dio.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'titles': candidateNames.join('|'),
          'prop': 'pageimages|description|extracts',
          'exintro': '1',
          'explaintext': '1',
          'exsentences': '1',
          'piprop': 'thumbnail',
          'pithumbsize': '600',
          'format': 'json',
        },
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final pages = response.data['query']?['pages'] as Map<String, dynamic>?;
        if (pages != null && pages.isNotEmpty) {
          final List<KnowledgeEntity> results = [];
          for (final page in pages.values) {
            final title = (page['title'] as String? ?? '').trim();
            if (title.isEmpty) continue;
            final desc = (page['description'] as String?)?.trim() ??
                (page['extract'] as String?)?.trim() ??
                'Notable figure';
            final thumb = page['thumbnail']?['source'] as String?;
            final pageId = (page['pageid'] ?? title).toString();

            results.add(KnowledgeEntity(
              id: pageId,
              title: title,
              description: desc,
              thumbnailUrl: thumb,
              wikipediaUrl: 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}',
            ));
          }
          if (results.isNotEmpty) return results;
        }
      }
    } catch (_) {}

    return _initialSeedPersonas
        .where((e) => !seenLower.contains(e.title.toLowerCase()))
        .take(limit)
        .toList();
  }

  Future<List<KnowledgeEntity>> getRelatedEntities(String title, {int limit = 6}) async {
    return getRecommendations([title], limit: limit);
  }

  /// RAG Overview & Gallery from Backend (`POST /api/v1/rag/query`)
  Future<RagQueryResponse> getRagOverview(String entityName) async {
    const String backendUrl = 'http://10.0.2.2:8000/api/v1/rag/query';
    const String localhostUrl = 'http://localhost:8000/api/v1/rag/query';

    final requestData = {
      "entity_name": entityName,
      "user_query": "Provide a comprehensive overview and biographical summary.",
      "top_k": 3,
      "similarity_threshold": 0.25,
      "format_type": "cards",
    };

    Response? response;
    // 1. Send POST request to Android emulator host address
    try {
      response = await _dio.post(
        backendUrl,
        data: requestData,
        options: Options(
          headers: {"Content-Type": "application/json"},
          sendTimeout: const Duration(seconds: 25),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );
    } catch (_) {
      // 2. Fallback to localhost address
      try {
        response = await _dio.post(
          localhostUrl,
          data: requestData,
          options: Options(
            headers: {"Content-Type": "application/json"},
            sendTimeout: const Duration(seconds: 25),
            receiveTimeout: const Duration(seconds: 25),
          ),
        );
      } catch (_) {
        response = null;
      }
    }

    if (response != null && response.statusCode == 200 && response.data != null) {
      try {
        return RagQueryResponse.fromJson(response.data);
      } catch (_) {
        // Fallback to Wikipedia client parsing below if backend JSON has unexpected types
      }
    }

    // 3. Robust client fallback: fetch Wikipedia biography and gallery so overview and gallery never fail
    try {
      final bio = await getEntityBiography(entityName);
      final gallery = await getEntityGallery(entityName);
      if (bio.isNotEmpty || gallery.isNotEmpty) {
        return RagQueryResponse.fromJson({
          'entity': entityName,
          'answer': bio.isNotEmpty ? bio : '$entityName is a well-known persona and notable figure.',
          'image_urls': gallery,
          'retrieved_chunks': [],
          'telemetry': {
            'hydration_latency_ms': 0,
            'vector_indexing_latency_ms': 0,
            'vector_search_latency_ms': 0,
            'llm_inference_latency_ms': 0,
            'total_execution_ms': 0,
            'avg_similarity_score': 0,
          },
        });
      }
    } catch (_) {}

    throw Exception('Failed to load overview from backend for $entityName');
  }

  Future<String> getEntityBiography(String title) async {
    if (_bioCache.containsKey(title)) return _bioCache[title]!;
    try {
      final response = await _dio.get(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
        queryParameters: {'pithumbsize': '600'},
        options: Options(headers: _headers),
      );

      if (response.statusCode == 200) {
        final extract = response.data['extract'] ?? '';
        _bioCache[title] = extract;
        return extract;
      }
      return '';
    } catch (e) {
      return '';
    }
  }

  Future<List<String>> getEntityGallery(String title) async {
    if (_galleryCache.containsKey(title)) return _galleryCache[title]!;
    try {
      final response1 = await _dio.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'prop': 'images',
          'titles': title,
          'imlimit': 50,
          'format': 'json',
        },
        options: Options(headers: _headers),
      );

      final pages = response1.data['query']?['pages'] as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return [];

      final page = pages.values.first;
      final images = page['images'] as List<dynamic>?;
      if (images == null) return [];

      List<String> filenames = [];
      for (var img in images) {
        final imgTitle = img['title'] as String?;
        if (imgTitle != null) {
          filenames.add(imgTitle);
        }
      }

      if (filenames.isEmpty) return [];

      final filenamesStr = filenames.join('|');
      final response2 = await _dio.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'titles': filenamesStr,
          'prop': 'imageinfo',
          'iiprop': 'url',
          'pithumbsize': '600',
          'format': 'json',
        },
        options: Options(headers: _headers),
      );

      final pages2 = response2.data['query']?['pages'] as Map<String, dynamic>?;
      if (pages2 == null || pages2.isEmpty) return [];

      List<String> validUrls = [];
      for (var p in pages2.values) {
        final imageinfo = p['imageinfo'] as List<dynamic>?;
        if (imageinfo != null && imageinfo.isNotEmpty) {
          final urlObj = imageinfo.first['url'];
          if (urlObj != null) {
            String imageUrl = urlObj.toString();
            final cleanUrl = imageUrl.split('?').first;
            final lower = cleanUrl.toLowerCase();

            if ((lower.endsWith('.jpg') || lower.endsWith('.jpeg')) &&
                !lower.contains('commons-logo') &&
                !lower.contains('wikiquote') &&
                !lower.contains('icon')) {
              validUrls.add(cleanUrl);
            }
          }
        }
      }
      _galleryCache[title] = validUrls;
      return validUrls;
    } catch (e) {
      return [];
    }
  }

  Future<String> getAIOverview(String bio) async {
    return bio;
  }
}
