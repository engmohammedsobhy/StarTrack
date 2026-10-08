import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class PersonaLabelService {
  /// Palette of distinct, soft pastel colors matching the Pinterest/iOS reference design:
  /// e.g. Pastel Sky Blue ("Flowers"), Pastel Soft Lime ("Tangerine"), Pastel Peach ("Almond"), etc.
  static const List<Color> pastelBackgroundColors = [
    Color(0xFFBAE6FD), // Sky Blue (like "Flowers")
    Color(0xFFD9F2B4), // Soft Lime Green (like "Tangerine")
    Color(0xFFFFDFBA), // Soft Peach / Almond (like "Almond")
    Color(0xFFE9D5FF), // Soft Lavender
    Color(0xFFFED7AA), // Soft Warm Apricot
    Color(0xFFFECDD3), // Soft Rose Pink
    Color(0xFFCCFBF1), // Soft Mint / Aqua
    Color(0xFFFEF08A), // Soft Butter Yellow
    Color(0xFFDDD6FE), // Soft Periwinkle
    Color(0xFFD1FAE5), // Soft Sage Green
    Color(0xFFFFE4E6), // Soft Blossom
    Color(0xFFE2E8F0), // Soft Slate
  ];

  static const Color labelTextColor = Color(0xFF1E293B); // Dark slate for clear contrast

  /// Curated high-precision label database for iconic figures & characters
  /// Curated high-precision label database for iconic figures & characters
  /// Grounded in authentic Wikidata attributes elevated to comprehensive, all-encompassing categories.
  static const Map<String, List<String>> _curatedLabels = {
    // Lionel Messi
    'lionel messi': [
      'Athlete',
      'Football Player',
      'Football Legend',
      'Argentina',
      'World Cup Champion',
      "Ballon d'Or Winner",
    ],
    // Sonic the Hedgehog
    'sonic the hedgehog': [
      'Video Game Character',
      'Fictional Character',
      'Blue',
      'Hedgehog',
      'Super Speed',
      'SEGA Icon',
      'Gaming Legend',
    ],
    'sonic': [
      'Video Game Character',
      'Fictional Character',
      'Blue',
      'Hedgehog',
      'Super Speed',
      'SEGA Icon',
    ],
    'cristiano ronaldo': [
      'Athlete',
      'Football Player',
      'Football Legend',
      'Portugal',
      'Champions League',
      'Sports',
    ],
    'diego maradona': [
      'Athlete',
      'Football Player',
      'Football Legend',
      'Argentina',
      'World Cup Champion',
      'Sports',
    ],
    'pele': [
      'Athlete',
      'Football Player',
      'Football Legend',
      'Brazil',
      '3x World Cup Champion',
      'Sports',
    ],
    'albert einstein': [
      'Scientist',
      'Theoretical Physicist',
      'Physics',
      'Nobel Laureate',
      'Cosmology',
      'Germany',
    ],
    'marie curie': [
      'Scientist',
      'Physicist',
      'Chemist',
      'Double Nobel Laureate',
      'Poland',
      'France',
    ],
    'isaac newton': [
      'Scientist',
      'Polymath',
      'Physicist',
      'Mathematician',
      'Scientific Revolution',
      'England',
    ],
    'nikola tesla': [
      'Scientist',
      'Innovator & Tech',
      'Inventor',
      'Electrical Engineer',
      'United States',
    ],
    'leonardo da vinci': [
      'Polymath',
      'Visual Artist',
      'Painter',
      'Inventor',
      'Renaissance',
      'Italy',
    ],
    'christian bale': [
      'Actor',
      'Cinema & Film',
      'Academy Award Winner',
      'Method Actor',
      'United Kingdom',
    ],
    'cillian murphy': [
      'Actor',
      'Cinema & Film',
      'Academy Award Winner',
      'Irish Actor',
      'Peaky Blinders',
    ],
    'gal gadot': [
      'Actor',
      'Cinema & Film',
      'Action Star',
      'Model',
      'Israel',
    ],
    'tom brady': [
      'Athlete',
      'Quarterback',
      'NFL Legend',
      '7x Super Bowl Champion',
      'United States',
      'Sports',
    ],
    'robert de niro': [
      'Actor',
      'Cinema & Film',
      'Academy Award Winner',
      'Hollywood Legend',
      'United States',
    ],
    'steve jobs': [
      'Entrepreneur',
      'Innovator & Tech',
      'Apple Co-Founder',
      'Technology',
      'United States',
    ],
    'elon musk': [
      'Entrepreneur',
      'Innovator & Tech',
      'SpaceX & Tesla',
      'Technology',
      'United States',
    ],
    'bill gates': [
      'Entrepreneur',
      'Software Pioneer',
      'Microsoft Founder',
      'Philanthropist',
      'United States',
    ],
    'alan turing': [
      'Scientist',
      'Computer Scientist',
      'Mathematician',
      'AI Visionary',
      'United Kingdom',
    ],
    'stephen hawking': [
      'Scientist',
      'Theoretical Physicist',
      'Cosmologist',
      'Physics',
      'United Kingdom',
    ],
    'charles darwin': [
      'Scientist',
      'Naturalist',
      'Evolutionary Biology',
      'Geologist',
      'United Kingdom',
    ],
    'mario': [
      'Video Game Character',
      'Fictional Character',
      'Nintendo Icon',
      'Platformer Hero',
      'Gaming Legend',
    ],
    'luigi': [
      'Video Game Character',
      'Fictional Character',
      'Nintendo Icon',
      'Mario Brother',
      'Green Hero',
    ],
    'pac-man': [
      'Video Game Character',
      'Fictional Character',
      'Arcade Legend',
      'Namco Mascot',
      'Retro Gaming',
    ],
    'link': [
      'Video Game Character',
      'Fictional Character',
      'Hero of Time',
      'Nintendo Legend',
      'Gaming',
    ],
    'crash bandicoot': [
      'Video Game Character',
      'Fictional Character',
      'PlayStation Icon',
      'Platformer',
      'Gaming Hero',
    ],
    'marilyn monroe': [
      'Actor',
      'Cinema & Film',
      'Hollywood Icon',
      'Golden Age Cinema',
      'United States',
    ],
    'audrey hepburn': [
      'Actor',
      'Cinema & Film',
      'Academy Award Winner',
      'Fashion Icon',
      'United Kingdom',
    ],
    'abraham lincoln': [
      'Political Leader',
      'President',
      'Statesman',
      'American History',
      'United States',
    ],
    'winston churchill': [
      'Political Leader',
      'Prime Minister',
      'Nobel Laureate',
      'Statesman',
      'United Kingdom',
    ],
    'mahatma gandhi': [
      'Political Leader',
      'Nonviolence',
      'Civil Rights Pioneer',
      'Spiritual Leader',
      'India',
    ],
    'nelson mandela': [
      'Political Leader',
      'President',
      'Nobel Peace Laureate',
      'Anti-Apartheid',
      'South Africa',
    ],
    'muhammad ali': [
      'Athlete',
      'Heavyweight Champion',
      'Boxing Legend',
      'Olympic Champion',
      'United States',
    ],
    'michael jordan': [
      'Athlete',
      'Basketball Player',
      '6x NBA Champion',
      'Olympic Champion',
      'United States',
    ],
    'bruce lee': [
      'Actor',
      'Martial Artist',
      'Action Cinema Legend',
      'Filmmaker',
      'Philosophy',
    ],
    'michael jackson': [
      'Musician',
      'Singer',
      'Pop Music',
      'Grammy Winner',
      'United States',
    ],
    'elvis presley': [
      'Musician',
      'Singer',
      'Rock and Roll',
      'Cultural Pioneer',
      'United States',
    ],
    'freddie mercury': [
      'Musician',
      'Singer',
      'Composer',
      'Rock Legend',
      'United Kingdom',
    ],
    'ludwig van beethoven': [
      'Musician',
      'Composer',
      'Classical Music',
      'Pianist',
      'Germany',
    ],
    'beethoven': [
      'Musician',
      'Composer',
      'Classical Music',
      'Pianist',
      'Germany',
    ],
    'wolfgang amadeus mozart': [
      'Musician',
      'Composer',
      'Classical Music',
      'Pianist',
      'Austria',
    ],
    'mozart': [
      'Musician',
      'Composer',
      'Classical Music',
      'Pianist',
      'Austria',
    ],
    'william shakespeare': [
      'Author',
      'Playwright',
      'Poet',
      'Literature',
      'England',
    ],
    'vincent van gogh': [
      'Visual Artist',
      'Painter',
      'Post-Impressionism',
      'Fine Arts',
      'Netherlands',
    ],
    'pablo picasso': [
      'Visual Artist',
      'Painter',
      'Sculptor',
      'Cubism Pioneer',
      'Spain',
    ],
    'alexander the great': [
      'Political Leader',
      'Military Commander',
      'King of Macedonia',
      'Ancient History',
    ],
    'julius caesar': [
      'Political Leader',
      'Military Commander',
      'Roman Dictator',
      'Ancient History',
      'Rome',
    ],
    'cleopatra': [
      'Political Leader',
      'Monarch',
      'Queen of Egypt',
      'Ancient History',
      'Egypt',
    ],
    'walt disney': [
      'Entrepreneur',
      'Filmmaker',
      'Animation Pioneer',
      'Cinema & Film',
      'United States',
    ],
  };

  /// Returns 3-6 distinct, descriptive labels for ANY persona
  static List<String> getLabelsForPersona(String title, [String? description]) {
    final cleanTitle = title.trim();
    final lowerTitle = cleanTitle.toLowerCase();

    // 1. Direct curated match
    if (_curatedLabels.containsKey(lowerTitle)) {
      return List<String>.from(_curatedLabels[lowerTitle]!);
    }

    // 2. Partial curated match (e.g. "Lionel Messi (footballer)")
    for (final entry in _curatedLabels.entries) {
      if (lowerTitle.contains(entry.key) || entry.key.contains(lowerTitle)) {
        return List<String>.from(entry.value);
      }
    }

    // 3. Dynamic extractor using entity description and title
    final List<String> extracted = [];
    final text = '$cleanTitle ${description ?? ''}'.toLowerCase();

    String? superCategory;
    String? domain;
    final List<String> primaryRoles = [];
    final List<String> countries = [];
    final List<String> accolades = [];

    // All-encompassing Super-Category and Domain Ontology
    const superCategoryMap = {
      'football player': ('Athlete', 'Sports'),
      'footballer': ('Athlete', 'Sports'),
      'soccer': ('Athlete', 'Sports'),
      'basketball': ('Athlete', 'Sports'),
      'nba': ('Athlete', 'Sports'),
      'baseball': ('Athlete', 'Sports'),
      'tennis': ('Athlete', 'Sports'),
      'boxer': ('Athlete', 'Sports'),
      'boxing': ('Athlete', 'Sports'),
      'athlete': ('Athlete', 'Sports'),
      'swimmer': ('Athlete', 'Sports'),
      'quarterback': ('Athlete', 'Sports'),
      'racing driver': ('Athlete', 'Sports'),
      'physicist': ('Scientist', 'Physics'),
      'physics': ('Scientist', 'Physics'),
      'chemist': ('Scientist', 'Chemistry'),
      'biologist': ('Scientist', 'Biology'),
      'mathematician': ('Scientist', 'Mathematics'),
      'astronomer': ('Scientist', 'Astronomy'),
      'scientist': ('Scientist', 'Science'),
      'computer scientist': ('Scientist', 'Technology'),
      'neuroscientist': ('Scientist', 'Medicine'),
      'polymath': ('Polymath', 'Science'),
      'actor': ('Actor', 'Cinema & Film'),
      'actress': ('Actor', 'Cinema & Film'),
      'film director': ('Filmmaker', 'Cinema & Film'),
      'filmmaker': ('Filmmaker', 'Cinema & Film'),
      'director': ('Filmmaker', 'Cinema & Film'),
      'musician': ('Musician', 'Music'),
      'singer': ('Musician', 'Music'),
      'composer': ('Musician', 'Music'),
      'pianist': ('Musician', 'Music'),
      'rapper': ('Musician', 'Music'),
      'president': ('Political Leader', 'Politics'),
      'prime minister': ('Political Leader', 'Politics'),
      'politician': ('Political Leader', 'Politics'),
      'head of state': ('Political Leader', 'Politics'),
      'monarch': ('Political Leader', 'History'),
      'king': ('Political Leader', 'History'),
      'queen': ('Political Leader', 'History'),
      'emperor': ('Political Leader', 'History'),
      'statesman': ('Political Leader', 'Politics'),
      'author': ('Author', 'Literature'),
      'writer': ('Author', 'Literature'),
      'novelist': ('Author', 'Literature'),
      'poet': ('Author', 'Literature'),
      'playwright': ('Author', 'Literature'),
      'painter': ('Visual Artist', 'Fine Arts'),
      'sculptor': ('Visual Artist', 'Fine Arts'),
      'architect': ('Visual Artist', 'Architecture'),
      'artist': ('Visual Artist', 'Fine Arts'),
      'philosopher': ('Philosopher', 'Philosophy'),
      'theologian': ('Philosopher', 'Philosophy'),
      'entrepreneur': ('Entrepreneur', 'Business'),
      'investor': ('Entrepreneur', 'Business'),
      'inventor': ('Innovator & Tech', 'Technology'),
      'engineer': ('Innovator & Tech', 'Engineering'),
      'astronaut': ('Astronaut', 'Space Exploration'),
      'general': ('Military Leader', 'Military History'),
      'military': ('Military Leader', 'Military History'),
      'video game character': ('Video Game Character', 'Pop Culture'),
      'fictional character': ('Fictional Character', 'Pop Culture'),
      'superhero': ('Fictional Character', 'Pop Culture'),
      'hedgehog': ('Hedgehog', 'Pop Culture'),
    };

    for (final entry in superCategoryMap.entries) {
      if (text.contains(entry.key)) {
        superCategory ??= entry.value.$1;
        domain ??= entry.value.$2;
        break;
      }
    }

    // Check specific professions
    const professions = {
      'football player': 'Football Player',
      'footballer': 'Football Player',
      'soccer': 'Football Player',
      'basketball': 'Basketball Player',
      'tennis': 'Tennis Player',
      'boxer': 'Boxer',
      'quarterback': 'Quarterback',
      'actor': 'Actor',
      'actress': 'Actress',
      'film director': 'Film Director',
      'filmmaker': 'Filmmaker',
      'physicist': 'Physicist',
      'theoretical physicist': 'Theoretical Physicist',
      'chemist': 'Chemist',
      'biologist': 'Biologist',
      'mathematician': 'Mathematician',
      'astronomer': 'Astronomer',
      'philosopher': 'Philosopher',
      'inventor': 'Inventor',
      'engineer': 'Engineer',
      'painter': 'Painter',
      'singer': 'Singer',
      'composer': 'Composer',
      'playwright': 'Playwright',
      'author': 'Author',
      'poet': 'Poet',
      'president': 'President',
      'prime minister': 'Prime Minister',
      'emperor': 'Emperor',
      'general': 'Military Commander',
      'video game character': 'Video Game Character',
      'fictional character': 'Fictional Character',
      'hedgehog': 'Hedgehog',
      'astronaut': 'Astronaut',
    };

    for (final p in professions.entries) {
      if (text.contains(p.key) && !primaryRoles.contains(p.value) && p.value != superCategory) {
        primaryRoles.add(p.value);
        if (primaryRoles.length >= 2) break;
      }
    }

    // Check nationality
    const nationalities = {
      'argentina': 'Argentina',
      'argentine': 'Argentine',
      'brazil': 'Brazil',
      'brazilian': 'Brazilian',
      'portugal': 'Portugal',
      'portuguese': 'Portuguese',
      'france': 'France',
      'french': 'French',
      'germany': 'Germany',
      'german': 'German',
      'italy': 'Italy',
      'italian': 'Italian',
      'spain': 'Spain',
      'spanish': 'Spanish',
      'england': 'England',
      'english': 'English',
      'britain': 'United Kingdom',
      'british': 'British',
      'scotland': 'Scottish',
      'ireland': 'Irish',
      'united states': 'American',
      'american': 'American',
      'canada': 'Canadian',
      'japan': 'Japanese',
      'china': 'Chinese',
      'russia': 'Russian',
      'poland': 'Polish',
      'egypt': 'Egyptian',
      'israel': 'Israeli',
      'south africa': 'South African',
      'india': 'Indian',
      'mexico': 'Mexican',
    };

    for (final n in nationalities.entries) {
      if (text.contains(n.key)) {
        countries.add(n.value);
        break;
      }
    }

    // Check traits & accolades
    if (text.contains('nobel')) accolades.add('Nobel Laureate');
    if (text.contains('oscar') || text.contains('academy award')) accolades.add('Academy Award Winner');
    if (text.contains('world cup')) accolades.add('World Cup Champion');
    if (text.contains('ballon d\'or')) accolades.add('Ballon d\'Or Winner');
    if (text.contains('olympic')) accolades.add('Olympic Medalist');
    if (text.contains('grammy')) accolades.add('Grammy Winner');
    if (text.contains('super bowl')) accolades.add('Super Bowl Champion');
    if (text.contains('speed')) accolades.add('Super Speed');

    if (superCategory != null) extracted.add(superCategory);
    for (final r in primaryRoles) {
      if (!extracted.contains(r)) extracted.add(r);
    }
    for (final c in countries) {
      if (!extracted.contains(c)) extracted.add(c);
    }
    for (final a in accolades) {
      if (!extracted.contains(a)) extracted.add(a);
    }
    if (domain != null && !extracted.contains(domain) && domain != superCategory) {
      extracted.add(domain);
    }

    // Never add generic filler words ("Notable Figure", "Icon", "Cultural Legend")
    return extracted.take(5).toList();
  }

  static final Map<String, List<String>> _attributeCache = {};

  /// Fetches and caches authentic Wikidata attributes directly from Wikidata API
  static Future<List<String>> fetchWikidataAttributesForEntity({
    String? wikidataId,
    required String title,
    String? description,
  }) async {
    final cacheKey = title.trim().toLowerCase();
    if (_attributeCache.containsKey(cacheKey) && _attributeCache[cacheKey]!.isNotEmpty) {
      return _attributeCache[cacheKey]!;
    }

    try {
      final dio = Dio();
      final Map<String, dynamic> params = {
        'action': 'wbgetentities',
        'props': 'claims|descriptions',
        'languages': 'en',
        'format': 'json',
      };
      if (wikidataId != null && wikidataId.trim().isNotEmpty && wikidataId.startsWith('Q')) {
        params['ids'] = wikidataId.trim();
      } else {
        params['titles'] = title.trim();
        params['sites'] = 'enwiki';
      }

      final response = await dio.get(
        'https://www.wikidata.org/w/api.php',
        queryParameters: params,
        options: Options(
          headers: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
          sendTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 4),
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final entities = response.data['entities'] as Map<String, dynamic>?;
        if (entities != null && entities.isNotEmpty) {
          for (final entry in entities.entries) {
            if (entry.key != '-1') {
              final claims = entry.value['claims'] as Map<String, dynamic>? ?? {};
              final targetQids = <String>[];

              for (final prop in ['P106', 'P27', 'P495', 'P166', 'P101', 'P136', 'P39', 'P31']) {
                final stmts = claims[prop] as List<dynamic>? ?? [];
                for (final stmt in stmts.take(3)) {
                  final val = stmt['mainsnak']?['datavalue']?['value'];
                  if (val is Map && val['id'] is String) {
                    final qid = val['id'] as String;
                    if (!targetQids.contains(qid)) {
                      targetQids.add(qid);
                    }
                  }
                  if (targetQids.length >= 12) break;
                }
                if (targetQids.length >= 12) break;
              }

              if (targetQids.isNotEmpty) {
                final labelResponse = await dio.get(
                  'https://www.wikidata.org/w/api.php',
                  queryParameters: {
                    'action': 'wbgetentities',
                    'ids': targetQids.join('|'),
                    'props': 'labels',
                    'languages': 'en',
                    'format': 'json',
                  },
                  options: Options(
                    headers: const {'User-Agent': 'StarTrackAI-Engine/2.3 (contact@startrack.ai)'},
                    sendTimeout: const Duration(seconds: 4),
                    receiveTimeout: const Duration(seconds: 4),
                  ),
                );

                if (labelResponse.statusCode == 200 && labelResponse.data != null) {
                  final labelEntities = labelResponse.data['entities'] as Map<String, dynamic>? ?? {};
                  final List<String> resolved = [];
                  for (final q in targetQids) {
                    final raw = labelEntities[q]?['labels']?['en']?['value'] as String?;
                    if (raw != null) {
                      final clean = cleanWikidataAttributeName(raw);
                      if (clean.isNotEmpty && !resolved.contains(clean)) {
                        resolved.add(clean);
                      }
                    }
                  }
                  if (resolved.isNotEmpty) {
                    _attributeCache[cacheKey] = resolved.take(6).toList();
                    return _attributeCache[cacheKey]!;
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    final fallback = getLabelsForPersona(title, description);
    if (fallback.isNotEmpty) {
      _attributeCache[cacheKey] = fallback;
    }
    return fallback;
  }

  static String cleanWikidataAttributeName(String raw) {
    var clean = raw.trim();
    final lower = clean.toLowerCase();
    if (lower == 'association football player') return 'Football Player';
    if (lower == 'association football club') return 'Football Club';
    if (lower == 'association football') return 'Football';
    if (lower == 'anthropomorphic hedgehog') return 'Hedgehog';
    if (lower == 'video game character') return 'Video Game Character';
    if (lower == 'united states of america') return 'United States';
    if (lower == 'argentine republic') return 'Argentina';
    if (lower == 'nobel prize in physics') return 'Nobel Prize in Physics';
    if (lower == 'nobel prize in chemistry') return 'Nobel Prize in Chemistry';
    if (lower == 'nobel peace prize') return 'Nobel Peace Prize';
    if (lower == 'human' || lower == 'male' || lower == 'female' || lower == 'wikimedia disambiguation page' || lower == 'wikimedia list article' || lower == 'notable figure' || lower == 'icon' || lower == 'cultural legend' || lower == 'person') {
      return '';
    }
    clean = clean.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
    if (clean.isEmpty) return '';
    return clean;
  }

  /// Comprehensive, all-encompassing labels for search and categorization
  static const List<String> popularSearchLabels = [
    'Athlete',
    'Scientist',
    'Actor',
    'Musician',
    'Political Leader',
    'Video Game Character',
    'Author',
    'Visual Artist',
    'Entrepreneur',
    'Philosopher',
    'Nobel Laureate',
    'World Cup Champion',
    'Academy Award Winner',
    'Football Player',
    'Theoretical Physicist',
    'Film Director',
    'Cinema & Film',
    'Technology',
    'Sports',
    'Physics',
    'Argentina',
    'United States',
    'France',
    'Japan',
    'United Kingdom',
    'Brazil',
  ];

  /// Returns a distinct pastel background color based on index.
  /// Guarantees that adjacent labels in any row display contrasting, different pastel colors
  /// matching the reference image palette.
  static Color getLabelBackgroundColor(int index, [String? label]) {
    return pastelBackgroundColors[index % pastelBackgroundColors.length];
  }

  /// Returns persona names that share the given label
  static List<String> getPersonaNamesForLabel(String queryLabel) {
    final clean = queryLabel.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final matching = <String>[];
    for (final entry in _curatedLabels.entries) {
      final pName = entry.key;
      final labels = entry.value;
      final matched = labels.any((l) {
        final lower = l.toLowerCase();
        return lower == clean || lower.contains(clean) || clean.contains(lower);
      });
      if (matched) {
        matching.add(_toTitleCase(pName));
      }
    }
    return matching;
  }

  /// Returns labels matching the query text for dynamic suggestions while typing.
  /// When query is empty, returns all popular comprehensive labels.
  static List<String> getMatchingLabels(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return popularSearchLabels;
    }

    final Set<String> allLabels = {};
    allLabels.addAll(popularSearchLabels);
    for (final labels in _curatedLabels.values) {
      allLabels.addAll(labels);
    }

    final matches = allLabels.where((label) {
      final lower = label.toLowerCase();
      return lower.contains(clean);
    }).toList();

    // Sort: prefix matches first, then shorter, then alphabetical
    matches.sort((a, b) {
      final aLower = a.toLowerCase();
      final bLower = b.toLowerCase();
      final aStarts = aLower.startsWith(clean);
      final bStarts = bLower.startsWith(clean);
      if (aStarts && !bStarts) return -1;
      if (!aStarts && bStarts) return 1;
      return aLower.compareTo(bLower);
    });

    return matches;
  }

  static String _toTitleCase(String text) {
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }
}
