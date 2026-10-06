import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/entity_model.dart';
import '../models/persona_search_result.dart';
import '../../../../core/constants.dart';
import '../../../person_details/data/models/rag_response_model.dart';

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

  final Set<String> _seenEntityTitles = {};
  final Map<String, String?> _categoryContinues = {};

  final List<String> _categories = const [
    'Category:Living_people',
    'Category:Academy_Award_winners',
    'Category:21st-century_American_actors',
    'Category:21st-century_musicians',
    'Category:Grammy_Award_winners',
    'Category:Presidents_of_the_United_States',
    'Category:Nobel_laureates',
    'Category:20th-century_philosophers',
    'Category:Association_football_players',
    'Category:Formula_One_drivers',
    'Category:World_Heavyweight_boxing_champions',
    'Category:Prime_Ministers_of_the_United_Kingdom',
    'Category:Tech_entrepreneurs',
    'Category:Film_directors',
    'Category:National_Basketball_Association_players',
    'Category:21st-century_American_actresses',
    'Category:Fellows_of_the_Royal_Society',
  ];

  static const Map<String, String> _curatedPeoplePool = {
    'Albert Einstein': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Einstein_1921_by_F_Schmutzer_-_restoration.jpg/600px-Einstein_1921_by_F_Schmutzer_-_restoration.jpg',
    'Marie Curie': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/12/Marie_Curie_c._1920s.jpg/600px-Marie_Curie_c._1920s.jpg',
    'Isaac Newton': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/GodfreyKneller-IsaacNewton-1689.jpg/600px-GodfreyKneller-IsaacNewton-1689.jpg',
    'Stephen Hawking': 'https://upload.wikimedia.org/wikipedia/commons/thumb/e/eb/Stephen_Hawking.StarChild.jpg/600px-Stephen_Hawking.StarChild.jpg',
    'Charles Darwin': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/2e/Charles_Darwin_seated_crop.jpg/600px-Charles_Darwin_seated_crop.jpg',
    'Nikola Tesla': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/79/Tesla_circa_1890.jpeg/600px-Tesla_circa_1890.jpeg',
    'Thomas Edison': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Thomas_Edison2.jpg/600px-Thomas_Edison2.jpg',
    'Galileo Galilei': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d4/Justus_Sustermans_-_Galileo_Galilei%2C_1636.jpg/600px-Justus_Sustermans_-_Galileo_Galilei%2C_1636.jpg',
    'Ada Lovelace': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a4/Ada_Lovelace_portrait.jpg/600px-Ada_Lovelace_portrait.jpg',
    'Alan Turing': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Alan_Turing_Aged_16.jpg/600px-Alan_Turing_Aged_16.jpg',
    'Steve Jobs': 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dc/Steve_Jobs_Headshot_2010-CROP_%28cropped_2%29.jpg/600px-Steve_Jobs_Headshot_2010-CROP_%28cropped_2%29.jpg',
    'Bill Gates': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a8/Bill_Gates_2017_%28cropped%29.jpg/600px-Bill_Gates_2017_%28cropped%29.jpg',
    'Elon Musk': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/34/Elon_Musk_Royal_Society_%28crop2%29.jpg/600px-Elon_Musk_Royal_Society_%28crop2%29.jpg',
    'Leonardo da Vinci': 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cb/Francesco_Melzi_-_Portrait_of_Leonardo.jpg/600px-Francesco_Melzi_-_Portrait_of_Leonardo.jpg',
    'Abraham Lincoln': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/Abraham_Lincoln_O-77_by_Gardner%2C_1863-crop.jpg/600px-Abraham_Lincoln_O-77_by_Gardner%2C_1863-crop.jpg',
    'George Washington': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Gilbert_Stuart_Williamstown_Portrait_of_George_Washington.jpg/600px-Gilbert_Stuart_Williamstown_Portrait_of_George_Washington.jpg',
    'Barack Obama': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8d/President_Barack_Obama.jpg/600px-President_Barack_Obama.jpg',
    'Winston Churchill': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/Sir_Winston_Churchill_-_Lady_Ittington_crop.jpg/600px-Sir_Winston_Churchill_-_Lady_Ittington_crop.jpg',
    'Mahatma Gandhi': 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Mahatma-Gandhi-studio-1931.jpg/600px-Mahatma-Gandhi-studio-1931.jpg',
    'Nelson Mandela': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/02/Nelson_Mandela_1994.jpg/600px-Nelson_Mandela_1994.jpg',
    'Martin Luther King Jr.': 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Martin_Luther_King%2C_Jr._NYWTS_6.jpg/600px-Martin_Luther_King%2C_Jr._NYWTS_6.jpg',
    'Leonardo DiCaprio': 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/25/Leonardo_DiCap_Nov_08.jpg/600px-Leonardo_DiCap_Nov_08.jpg',
    'Tom Cruise': 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/50/Tom_Cruise_by_Gage_Skidmore_2.jpg/600px-Tom_Cruise_by_Gage_Skidmore_2.jpg',
    'Marilyn Monroe': 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Marilyn_Monroe_-_1953.jpg/600px-Marilyn_Monroe_-_1953.jpg',
    'Wolfgang Amadeus Mozart': 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/Wolfgang-amadeus-mozart_1.jpg/600px-Wolfgang-amadeus-mozart_1.jpg',
    'Ludwig van Beethoven': 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6f/Beethoven.jpg/600px-Beethoven.jpg',
    'Michael Jackson': 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/31/Michael_Jackson_in_1988.jpg/600px-Michael_Jackson_in_1988.jpg',
    'William Shakespeare': 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a2/Shakespeare.jpg/600px-Shakespeare.jpg',
    'Vincent van Gogh': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b2/Vincent_van_Gogh_-_Self-Portrait_-_Google_Art_Project.jpg/600px-Vincent_van_Gogh_-_Self-Portrait_-_Google_Art_Project.jpg',
    'Pablo Picasso': 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/98/Pablo_picasso_1962.jpg/600px-Pablo_picasso_1962.jpg',
    'Lionel Messi': 'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b4/Lionel-Messi-Argentina-2022-World-Cup_%28cropped%29.jpg/600px-Lionel-Messi-Argentina-2022-World-Cup_%28cropped%29.jpg',
    'Cristiano Ronaldo': 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8c/Cristiano_Ronaldo_2018.jpg/600px-Cristiano_Ronaldo_2018.jpg',
  };

  KnowledgeRepository(this._dio);

  /// Helper function to transform thumbnail URLs into high-resolution images safely handled by Wikimedia CDN.
  /// Ensures pre-encoded URLs aren't broken and prevents double percent-encoding.
  String _getHighResImageUrl(String url) {
    if (url.isEmpty) return url;
    String cleaned = url.trim();
    if (cleaned.startsWith('//')) {
      cleaned = 'https:$cleaned';
    } else if (cleaned.startsWith('http://')) {
      cleaned = cleaned.replaceFirst('http://', 'https://');
    }
    return cleaned;
  }

  /// Helper function to perform client-side checks for direct Wikipedia API calls.
  /// Non-destructive exclusion-based filter.
  /// Rejects ONLY explicit non-person entities (movies, albums, wars, cities, etc.)
  /// while allowing real people, historical figures, voice actors, musical artists, and characters.
  bool _isStrictlyPerson(String title, String? description, String? extract) {
    if (title.trim().isEmpty) return false;

    final lowerTitle = title.trim().toLowerCase();
    final lowerDesc = (description ?? '').trim().toLowerCase();
    final lowerExtract = (extract ?? '').trim().toLowerCase();
    final fullText = '$lowerTitle $lowerDesc $lowerExtract';

    // 1. Immediate Auto-Rejection Rules for Titles (Prefixes or Disambiguations)
    const titlePrefixRejections = [
      'list of ',
      'category:',
      'outline of ',
      'history of ',
      'timeline of ',
      'index of ',
      'disambiguation',
      'file:',
      'template:',
      'culture of ',
      'music of ',
      'cinema of ',
      'economy of ',
      'geography of ',
      'demographics of ',
    ];

    for (final prefix in titlePrefixRejections) {
      if (lowerTitle.startsWith(prefix) || lowerTitle == prefix.trim()) {
        return false;
      }
    }

    if (lowerTitle.contains('disambiguation') ||
        lowerDesc.startsWith('list of ') ||
        lowerDesc.startsWith('category:')) {
      return false;
    }

    // 2. Standalone broad topic titles
    const exactNonPersonTitles = {
      'world',
      'hello, world',
      'hello world',
      'hello, world!',
      'world war',
      'world war i',
      'world war ii',
      'world war 1',
      'world war 2',
      'science',
      'technology',
      'philosophy',
      'politics',
      'art',
      'music',
      'cinema',
      'film',
      'history',
      'geography',
      'mathematics',
      'physics',
      'chemistry',
      'biology',
      'literature',
      'sports',
      'football',
      'basketball',
      'earth',
      'nature',
      'universe',
      'code',
      'software',
      'program',
      'manifesto',
      'event',
      'game',
      'sport',
    };

    if (exactNonPersonTitles.contains(lowerTitle)) {
      return false;
    }

    // 3. Parenthetical non-person entity types in title
    if (lowerTitle.contains('(film)') ||
        lowerTitle.contains('(movie)') ||
        lowerTitle.contains('(album)') ||
        lowerTitle.contains('(song)') ||
        lowerTitle.contains('(book)') ||
        lowerTitle.contains('(novel)') ||
        lowerTitle.contains('(series)') ||
        lowerTitle.contains('(tv series)') ||
        lowerTitle.contains('(television series)') ||
        lowerTitle.contains('(season)') ||
        lowerTitle.contains('(video game)') ||
        lowerTitle.contains('(game)') ||
        lowerTitle.contains('(election)') ||
        lowerTitle.contains('(soundtrack)') ||
        lowerTitle.contains('(constituency)') ||
        lowerTitle.contains('(district)') ||
        lowerTitle.contains('(city)') ||
        lowerTitle.contains('(country)') ||
        lowerTitle.contains('(company)') ||
        lowerTitle.contains('(corporation)') ||
        lowerTitle.contains('(stadium)') ||
        lowerTitle.contains('(university)') ||
        lowerTitle.contains('(school)') ||
        lowerTitle.contains('(airport)') ||
        lowerTitle.contains('(station)') ||
        lowerTitle.contains('(party)') ||
        lowerTitle.contains('(river)') ||
        lowerTitle.contains('(mountain)')) {
      return false;
    }

    // 4. Title term rejections for explicit non-persons
    const titleNonPersonTerms = [
      'world war',
      'battle of',
      'treaty of',
      'election',
      'referendum',
      'university of',
      'stadium',
      'airport',
      'station',
      'corporation',
      'manifesto',
      'discography',
      'filmography',
      'military campaign',
    ];

    for (final term in titleNonPersonTerms) {
      if (lowerTitle.contains(term)) {
        return false;
      }
    }

    // Person role/identity indicators
    final hasPersonRole = fullText.contains('actor') ||
        fullText.contains('actress') ||
        fullText.contains('director') ||
        fullText.contains('producer') ||
        fullText.contains('filmmaker') ||
        fullText.contains('singer') ||
        fullText.contains('musician') ||
        fullText.contains('songwriter') ||
        fullText.contains('composer') ||
        fullText.contains('politician') ||
        fullText.contains('scientist') ||
        fullText.contains('physicist') ||
        fullText.contains('chemist') ||
        fullText.contains('biologist') ||
        fullText.contains('mathematician') ||
        fullText.contains('philosopher') ||
        fullText.contains('author') ||
        fullText.contains('writer') ||
        fullText.contains('poet') ||
        fullText.contains('artist') ||
        fullText.contains('painter') ||
        fullText.contains('sculptor') ||
        fullText.contains('athlete') ||
        fullText.contains('footballer') ||
        fullText.contains('boxer') ||
        fullText.contains('king') ||
        fullText.contains('queen') ||
        fullText.contains('president') ||
        fullText.contains('prime minister') ||
        fullText.contains('emperor') ||
        fullText.contains('monarch') ||
        fullText.contains('general') ||
        fullText.contains('inventor') ||
        fullText.contains('fictional character') ||
        fullText.contains('character in') ||
        lowerDesc.startsWith('character') ||
        fullText.contains('playable character') ||
        fullText.contains('voice actor') ||
        fullText.contains('voiced by') ||
        fullText.contains('portrayed by') ||
        fullText.contains('played by') ||
        fullText.contains('born ') ||
        fullText.contains('(born ');

    // 5. Explicit non-person category indicators in title or description
    final isMovieOrFilm = lowerDesc.contains(' film') ||
        lowerDesc.startsWith('film ') ||
        lowerDesc.contains('film by') ||
        lowerDesc.contains('feature film') ||
        lowerDesc.contains('short film') ||
        lowerDesc.contains('animated film') ||
        lowerDesc.contains('horror film') ||
        lowerDesc.contains('comedy film') ||
        lowerDesc.contains('thriller film') ||
        lowerDesc.contains('action film') ||
        lowerDesc.contains('movie by') ||
        lowerDesc.contains('is a movie');

    if (isMovieOrFilm && !hasPersonRole) {
      return false;
    }

    final isAlbumOrSong = lowerDesc.contains('album') ||
        lowerDesc.contains('song') ||
        lowerDesc.contains('single by') ||
        lowerDesc.contains('studio album') ||
        lowerDesc.contains('debut album') ||
        lowerDesc.contains('compilation album') ||
        lowerDesc.contains('discography');

    if (isAlbumOrSong && !hasPersonRole) {
      return false;
    }

    final isTVSeries = lowerDesc.contains('television series') ||
        lowerDesc.contains('tv series') ||
        lowerDesc.contains('animated series') ||
        lowerDesc.contains('sitcom');

    if (isTVSeries && !hasPersonRole) {
      return false;
    }

    final isVideoGame = lowerDesc.contains('video game') ||
        lowerDesc.contains('action-adventure game') ||
        lowerDesc.contains('role-playing game') ||
        lowerDesc.contains('first-person shooter');

    if (isVideoGame && !hasPersonRole) {
      return false;
    }

    final isCompanyOrOrg = lowerDesc.contains('company') ||
        lowerDesc.contains('corporation') ||
        lowerDesc.contains('multinational technology') ||
        lowerDesc.contains('racing team');

    if (isCompanyOrOrg && !hasPersonRole) {
      return false;
    }

    final isVehicleOrProduct = lowerDesc.contains('motor vehicle') ||
        lowerDesc.contains('automobile') ||
        lowerDesc.contains('car model') ||
        lowerDesc.contains('aircraft');

    if (isVehicleOrProduct && !hasPersonRole) {
      return false;
    }

    final isEventOrWar = lowerDesc.contains('event') ||
        lowerDesc.contains('pay-per-view') ||
        lowerDesc.contains('battle of') ||
        lowerDesc.contains('referendum') ||
        lowerDesc.contains('election');

    if (isEventOrWar && !hasPersonRole) {
      return false;
    }

    final isTechOrMath = lowerDesc.contains('algorithm') ||
        lowerDesc.contains('neural network') ||
        lowerDesc.contains('software') ||
        lowerDesc.contains('computer program') ||
        lowerDesc.contains('metric used');

    if (isTechOrMath && !hasPersonRole) {
      return false;
    }

    final isGeographic = lowerDesc.contains('country in') ||
        lowerDesc.contains('city in') ||
        lowerDesc.contains('capital of') ||
        lowerDesc.contains('municipality in') ||
        lowerDesc.contains('village in') ||
        lowerDesc.contains('town in') ||
        lowerDesc.contains('river in') ||
        lowerDesc.contains('mountain in') ||
        lowerDesc.contains('stadium in') ||
        lowerDesc.contains('airport in') ||
        lowerDesc.contains('station in');

    if (isGeographic && !hasPersonRole) {
      return false;
    }

    // ALLOW EVERYTHING ELSE!
    return true;
  }

  Future<List<KnowledgeEntity>> getTrendingEntities({int page = 1, bool refresh = false}) async {
    try {
      if (page == 1 || refresh) {
        _seenEntityTitles.clear();
        _categoryContinues.clear();
      }

      const int pageSize = 12;
      final List<KnowledgeEntity> entities = [];
      final Set<String> candidateTitles = {};

      // 1. Curated Famous People Pool across politics, science, cinema, music, sports, literature, art
      final List<String> famousPeople = [
        // Science & Technology
        'Albert Einstein', 'Marie Curie', 'Isaac Newton', 'Stephen Hawking', 'Charles Darwin',
        'Nikola Tesla', 'Thomas Edison', 'Galileo Galilei', 'Richard Feynman', 'Ada Lovelace',
        'Alan Turing', 'Carl Sagan', 'James Clerk Maxwell', 'Louis Pasteur', 'Alexander Fleming',
        'Steve Jobs', 'Bill Gates', 'Elon Musk', 'Mark Zuckerberg', 'Jeff Bezos',
        'Tim Berners-Lee', 'Linus Torvalds', 'Larry Page', 'Sergey Brin', 'Satya Nadella',
        'Sundar Pichai', 'Jensen Huang', 'Sam Altman', 'Warren Buffett', 'Tim Cook',
        'Sigmund Freud', 'Carl Jung', 'Niels Bohr', 'Erwin Schrödinger', 'Enrico Fermi',
        'Alexander Graham Bell', 'Guglielmo Marconi', 'Dmitri Mendeleev', 'Michael Faraday', 'Gregor Mendel',

        // Cinema & Performing Arts
        'Leonardo DiCaprio', 'Tom Cruise', 'Brad Pitt', 'Angelina Jolie', 'Scarlett Johansson',
        'Morgan Freeman', 'Tom Hanks', 'Robert De Niro', 'Al Pacino', 'Meryl Streep',
        'Charlie Chaplin', 'Marilyn Monroe', 'Audrey Hepburn', 'Marlon Brando', 'Clint Eastwood',
        'Steven Spielberg', 'Martin Scorsese', 'Quentin Tarantino', 'Christopher Nolan', 'Alfred Hitchcock',
        'Stanley Kubrick', 'Akira Kurosawa', 'Denzel Washington', 'Viola Davis', 'Cate Blanchett',
        'Robert Downey Jr.', 'Keanu Reeves', 'Johnny Depp', 'Samuel L. Jackson', 'Harrison Ford',
        'Will Smith', 'Heath Ledger', 'Joaquin Phoenix', 'Cillian Murphy', 'Margot Robbie',
        'Timothée Chalamet', 'Zendaya', 'Florence Pugh', 'Pedro Pascal', 'Ryan Gosling',
        'Emma Stone', 'Christian Bale', 'Hugh Jackman', 'Matt Damon', 'Ben Affleck',
        'Kate Winslet', 'Keira Knightley', 'Ian McKellen', 'Patrick Stewart', 'Anthony Hopkins',
        'Dwayne Johnson', 'Anne Hathaway', 'Natalie Portman', 'Chris Hemsworth', 'Chris Evans',
        'Gal Gadot', 'Tom Holland', 'Daniel Day-Lewis', 'Gary Oldman', 'Ke Huy Quan',

        // Music
        'Wolfgang Amadeus Mozart', 'Ludwig van Beethoven', 'Johann Sebastian Bach', 'Frédéric Chopin', 'Pyotr Ilyich Tchaikovsky',
        'Michael Jackson', 'Elvis Presley', 'Bob Marley', 'John Lennon', 'Paul McCartney',
        'Freddie Mercury', 'David Bowie', 'Prince', 'Madonna', 'Beyoncé',
        'Taylor Swift', 'Rihanna', 'Eminem', 'Tupac Shakur', 'Snoop Dogg',
        'Dr. Dre', 'Jay-Z', 'Kanye West', 'Drake', 'Adele',
        'Lady Gaga', 'Bruno Mars', 'Ed Sheeran', 'Justin Bieber', 'Billie Eilish',
        'Ariana Grande', 'Elton John', 'Frank Sinatra', 'Stevie Wonder', 'Louis Armstrong',
        'Miles Davis', 'Luciano Pavarotti', 'Bob Dylan', 'Bruce Springsteen', 'Whitney Houston',

        // Politics & World Leaders
        'Abraham Lincoln', 'George Washington', 'Thomas Jefferson', 'Franklin D. Roosevelt', 'Theodore Roosevelt',
        'John F. Kennedy', 'Barack Obama', 'Winston Churchill', 'Queen Elizabeth II', 'Mahatma Gandhi',
        'Nelson Mandela', 'Martin Luther King Jr.', 'Julius Caesar', 'Alexander the Great', 'Napoleon',
        'Cleopatra', 'Augustus', 'Marcus Aurelius', 'Joan of Arc', 'Catherine the Great',
        'Otto von Bismarck', 'Charles de Gaulle', 'Indira Gandhi', 'Margaret Thatcher', 'Lee Kuan Yew',
        'Mikhail Gorbachev', 'Angela Merkel', 'Benjamin Franklin', 'Simón Bolívar', 'Jawaharlal Nehru',
        'Mustafa Kemal Atatürk', 'Sun Yat-sen', 'Kofi Annan', 'Dalai Lama', 'Pope John Paul II',

        // Philosophy, Literature & Art
        'Leonardo da Vinci', 'Vincent van Gogh', 'Pablo Picasso', 'Michelangelo', 'Claude Monet',
        'Rembrandt', 'Salvador Dalí', 'Frida Kahlo', 'William Shakespeare', 'Homer',
        'Dante Alighieri', 'Miguel de Cervantes', 'Leo Tolstoy', 'Fyodor Dostoevsky', 'Victor Hugo',
        'Mark Twain', 'Charles Dickens', 'Jane Austen', 'Virginia Woolf', 'Ernest Hemingway',
        'F. Scott Fitzgerald', 'Edgar Allan Poe', 'Agatha Christie', 'Arthur Conan Doyle', 'J.K. Rowling',
        'Stephen King', 'George R.R. Martin', 'J.R.R. Tolkien', 'Gabriel García Márquez', 'Franz Kafka',
        'Socrates', 'Plato', 'Aristotle', 'René Descartes', 'Immanuel Kant',
        'Friedrich Nietzsche', 'Karl Marx', 'John Locke', 'Voltaire', 'Confucius',

        // Sports
        'Lionel Messi', 'Cristiano Ronaldo', 'Pelé', 'Diego Maradona', 'Johan Cruyff',
        'Zinedine Zidane', 'Ronaldinho', 'Kylian Mbappé', 'Michael Jordan', 'LeBron James',
        'Kobe Bryant', 'Shaquille O\'Neal', 'Stephen Curry', 'Muhammad Ali', 'Mike Tyson',
        'Manny Pacquiao', 'Roger Federer', 'Rafael Nadal', 'Novak Djokovic', 'Serena Williams',
        'Usain Bolt', 'Michael Phelps', 'Lewis Hamilton', 'Ayrton Senna', 'Michael Schumacher',
        'Tiger Woods', 'Wayne Gretzky', 'Tom Brady', 'Simone Biles'
      ];

      final int startIndex = (page - 1) * pageSize;
      if (startIndex < famousPeople.length) {
        final int endIndex = (startIndex + pageSize).clamp(0, famousPeople.length);
        candidateTitles.addAll(famousPeople.sublist(startIndex, endIndex));
      }

      // 2. Query Wikipedia Category APIs strictly targeting people
      final List<String> categoryList = List.from(_categories);

      int categoryOffset = 0;
      while (candidateTitles.length < pageSize * 2 && categoryOffset < categoryList.length) {
        final catIndex = ((page - 1) + categoryOffset) % categoryList.length;
        final categoryName = categoryList[catIndex];
        try {
          final catTitles = await _fetchCategoryMembers(categoryName, refresh: refresh);
          candidateTitles.addAll(catTitles);
        } catch (_) {
          // Ignore category errors
        }
        categoryOffset++;
      }

      // Process Candidate Summaries
      if (candidateTitles.isNotEmpty) {
        final futures = candidateTitles.map((title) async {
          if (_seenEntityTitles.contains(title.toLowerCase())) return null;
          return await _fetchPageSummary(title);
        });

        final results = await Future.wait(futures);
        for (var entity in results) {
          if (entity != null &&
              _isValidEntity(entity) &&
              _isStrictlyPerson(entity.title, entity.description, entity.description) &&
              !_seenEntityTitles.contains(entity.title.toLowerCase())) {
            entities.add(entity);
            _seenEntityTitles.add(entity.title.toLowerCase());
            if (entities.length >= pageSize) break;
          }
        }
      }

      // 3. Clean up and apply strict person verification to ALL fetched results before returning
      final filteredEntities = entities.where((entity) {
        return _isValidEntity(entity) && _isStrictlyPerson(entity.title, entity.description, entity.description);
      }).toList();

      return filteredEntities;
    } catch (e) {
      throw Exception('Error fetching trending entities: $e');
    }
  }

  Future<List<KnowledgeEntity>> getCategoryEntities(String categoryName, {int limit = 20, bool refresh = false}) async {
    try {
      if (refresh) {
        _categoryContinues.remove(categoryName);
      }
      final members = await _fetchCategoryMembers(categoryName, refresh: refresh);
      final List<KnowledgeEntity> entities = [];

      for (final title in members) {
        if (_seenEntityTitles.contains(title.toLowerCase())) continue;
        final entity = await _fetchPageSummary(title);
        if (entity != null &&
            _isValidEntity(entity) &&
            _isStrictlyPerson(entity.title, entity.description, entity.description)) {
          entities.add(entity);
          _seenEntityTitles.add(entity.title.toLowerCase());
          if (entities.length >= limit) break;
        }
      }
      return entities;
    } catch (e) {
      return [];
    }
  }

  bool _isValidEntity(KnowledgeEntity entity) {
    if (entity.title.isEmpty) return false;
    final thumb = entity.thumbnailUrl;
    if (thumb == null || thumb.trim().isEmpty) return false;

    final lowerTitle = entity.title.toLowerCase();
    if (lowerTitle.startsWith('list of') ||
        lowerTitle.startsWith('category:') ||
        lowerTitle.startsWith('file:') ||
        lowerTitle.contains('disambiguation')) {
      return false;
    }
    return _isStrictlyPerson(entity.title, entity.description, entity.description);
  }

  Future<KnowledgeEntity?> _fetchPageSummary(String title) async {
    try {
      final response = await _dio.get(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
        queryParameters: {
          'pithumbsize': '600',
        },
        options: Options(headers: _headers),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final entity = _parseArticle(data);
        final extract = data['extract'] as String?;
        final desc = data['description'] as String?;
        if (_isStrictlyPerson(entity.title, desc, extract)) {
          return entity;
        }
      }
    } catch (_) {
      // Ignore individual page fetch failures
    }
    return null;
  }

  Future<List<String>> _fetchCategoryMembers(String categoryTitle, {bool refresh = false}) async {
    if (refresh) {
      _categoryContinues.remove(categoryTitle);
    }
    final continueToken = _categoryContinues[categoryTitle];
    final Map<String, dynamic> queryParams = {
      'action': 'query',
      'list': 'categorymembers',
      'cmtitle': categoryTitle,
      'cmlimit': '50',
      'cmtype': 'page',
      'pithumbsize': '600',
      'format': 'json',
    };
    if (continueToken != null) {
      queryParams['cmcontinue'] = continueToken;
    }

    final response = await _dio.get(
      'https://en.wikipedia.org/w/api.php',
      queryParameters: queryParams,
      options: Options(headers: _headers),
    );

    if (response.statusCode == 200 && response.data != null) {
      final nextContinue = response.data['continue']?['cmcontinue'] as String?;
      if (nextContinue != null) {
        _categoryContinues[categoryTitle] = nextContinue;
      }

      final members = response.data['query']?['categorymembers'] as List<dynamic>?;
      if (members != null) {
        final memberTitles = members
            .map((m) => m['title'] as String?)
            .whereType<String>()
            .where((t) => !t.startsWith('List of') && !t.startsWith('Category:'))
            .toList();
        return memberTitles;
      }
    }
    return [];
  }

  KnowledgeEntity _parseArticle(Map<String, dynamic> article) {
    final title = article['normalizedtitle'] ?? article['title'] ?? '';
    final rawTitle = article['title'] ?? '';

    String? thumbnailUrl = article['thumbnail']?['source'] ??
        article['originalimage']?['source'] ??
        article['original']?['source'] ??
        _curatedPeoplePool[title] ??
        _curatedPeoplePool[rawTitle];

    if (thumbnailUrl != null) {
      thumbnailUrl = _getHighResImageUrl(thumbnailUrl);
    }

    final extract = article['extract'] as String?;
    final desc = article['description'] as String?;
    final combinedDesc = (desc != null && desc.isNotEmpty) ? desc : extract;

    return KnowledgeEntity(
      id: rawTitle.isNotEmpty ? rawTitle : title,
      title: article['normalizedtitle'] ?? article['title'] ?? '',
      description: combinedDesc,
      thumbnailUrl: thumbnailUrl,
      wikipediaUrl: article['content_urls']?['desktop']?['page'],
    );
  }

  Future<String> getEntityBiography(String title) async {
    if (_bioCache.containsKey(title)) return _bioCache[title]!;
    try {
      final response = await _dio.get(
        'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(title)}',
        queryParameters: {
          'pithumbsize': '600',
        },
        options: Options(headers: _headers),
      );

      if (response.statusCode == 200) {
        final extract = response.data['extract'] ?? '';
        _bioCache[title] = extract;
        return extract;
      }
      return '';
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait a moment.');
      }
      throw Exception('Error fetching biography: $e');
    } catch (e) {
      throw Exception('Error fetching biography: $e');
    }
  }

  Future<List<KnowledgeEntity>> searchEntities(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];
    if (_searchCache.containsKey(cleanQuery)) return _searchCache[cleanQuery]!;

    final String encodedQuery = Uri.encodeComponent(cleanQuery);
    List<dynamic>? rawList;

    // 1. Make GET request to Android emulator host address (10.0.2.2:8000)
    try {
      final response = await _dio.get(
        'http://10.0.2.2:8000/api/v1/search/personas?q=$encodedQuery',
        options: Options(
          headers: _headers,
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
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
      }
    } catch (_) {
      // 2. Fallback to localhost (for desktop/web/local environment)
      try {
        final response = await _dio.get(
          'http://localhost:8000/api/v1/search/personas?q=$encodedQuery',
          options: Options(
            headers: _headers,
            sendTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 5),
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
        }
      } catch (_) {
        rawList = null;
      }
    }

    if (rawList == null || rawList.isEmpty) {
      return [];
    }

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
      );

      entities.add(entity);
      seenTitles.add(title.toLowerCase());
    }

    _searchCache[cleanQuery] = entities;
    return entities;
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
              imageUrl = _getHighResImageUrl(cleanUrl);
              validUrls.add(imageUrl);
            }
          }
        }
      }
      _galleryCache[title] = validUrls;
      return validUrls;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw Exception('Rate limit exceeded. Please wait a moment.');
      }
      throw Exception('Error fetching images: $e');
    } catch (e) {
      throw Exception('Error fetching images: $e');
    }
  }

  Future<List<KnowledgeEntity>> getRecommendations(String title, {List<String> excludeNames = const []}) async {
    try {
      String exclusionRule = excludeNames.isNotEmpty ? "Do NOT include any of these names: ${excludeNames.join(', ')}. " : "";
      String prompt = "${exclusionRule}Give me exactly 12 famous real people similar to $title. Return ONLY a valid JSON array of strings: [\"Name 1\", \"Name 2\", \"Name 3\", \"Name 4\", \"Name 5\", \"Name 6\", \"Name 7\", \"Name 8\", \"Name 9\", \"Name 10\", \"Name 11\", \"Name 12\"].";

      final response = await _dio.post(
        '${AppConstants.groqBaseUrl}/chat/completions',
        data: {
          "model": "openai/gpt-oss-120b",
          "messages": [
            {"role": "user", "content": prompt}
          ],
        },
        options: Options(
          headers: {
            "Authorization": "Bearer ${AppConstants.groqApiKey}",
            "Content-Type": "application/json",
          },
        ),
      );

      String content = response.data['choices'][0]['message']['content'] as String;

      // Strip markdown
      content = content.replaceAll('```json', '').replaceAll('```', '').trim();

      int startIndex = content.indexOf('[');
      int endIndex = content.lastIndexOf(']');
      if (startIndex != -1 && endIndex != -1 && startIndex < endIndex) {
        content = content.substring(startIndex, endIndex + 1);
      }

      final List<dynamic> names = jsonDecode(content);
      final List<KnowledgeEntity> recommendations = [];

      for (String name in names.take(12)) {
        try {
          final entities = await searchEntities(name);
          if (entities.isNotEmpty) {
            recommendations.add(entities.first);
          }
        } catch (_) {}
      }

      return recommendations;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData != null && responseData.toString().contains('invalid_api_key')) {
        throw Exception("AI Engine unavailable: Invalid or expired API Key.");
      }
      throw Exception('Network error: ${responseData ?? e.message}');
    } catch (e) {
      throw Exception('Error parsing recommendations: $e');
    }
  }

  Future<String> getAIOverview(String bio) async {
    if (bio.isEmpty) return '';
    try {
      final prompt = "Introduce this person to a reader who has NEVER heard of them before. Start with a clear 1-2 sentence introductory hook explaining exactly who they are, their profession, and why they are famous. Then provide a highly concise, structured overview. Use markdown. Include a bold 'Overview' section with bullet points for 'Full Name', 'Birthdate', 'Known For', and 'Nationality'. Then a bold 'Career Highlights' section with 2-3 short bullet points. Keep it extremely brief.\n\n$bio";

      final response = await _dio.post(
        '${AppConstants.groqBaseUrl}/chat/completions',
        data: {
          "model": "openai/gpt-oss-120b",
          "messages": [
            {"role": "user", "content": prompt}
          ]
        },
        options: Options(
          headers: {
            "Authorization": "Bearer ${AppConstants.groqApiKey}",
            "Content-Type": "application/json",
          },
        ),
      );

      return response.data['choices'][0]['message']['content']?.toString().trim() ?? '';
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData != null && responseData.toString().contains('invalid_api_key')) {
        throw Exception("AI Engine unavailable: Invalid or expired API Key.");
      }
      throw Exception('Network error: ${responseData ?? e.message}');
    } catch (e) {
      throw Exception('Error fetching AI overview: $e');
    }
  }

  Future<RagQueryResponse> getRagOverview(String entityName) async {
    try {
      final response = await _dio.post(
        '${AppConstants.ragBackendUrl}/api/v1/rag/query',
        data: {
          "entity_name": entityName,
          "wikipedia_title": entityName.replaceAll(' ', '_'),
          "user_query": "Provide a highly concise, structured overview. Use markdown. Include a bold Overview section with bullet points for Full Name, Birthdate, Known For, and Nationality. Then a bold Career Highlights section with 2-3 short bullet points. Keep it extremely brief.",
          "top_k": 3,
          "similarity_threshold": 0.25
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return RagQueryResponse.fromJson(response.data);
      } else {
        throw Exception("Invalid response from RAG backend");
      }
    } catch (e) {
      // Fallback
      try {
        final bio = await getEntityBiography(entityName);
        final answer = await getAIOverview(bio);
        final images = await getEntityGallery(entityName);
        return RagQueryResponse(
          entity: entityName,
          answer: answer.isNotEmpty ? answer : "No overview available.",
          imageUrls: images,
          retrievedChunks: [],
          telemetry: PerformanceTelemetry(
            hydrationLatencyMs: 0.0,
            vectorIndexingLatencyMs: 0.0,
            vectorSearchLatencyMs: 0.0,
            llmInferenceLatencyMs: 0.0,
            totalExecutionMs: 0.0,
            avgSimilarityScore: 0.0,
          ),
        );
      } catch (fallbackError) {
        throw Exception("Both RAG backend and fallback failed: $fallbackError");
      }
    }
  }
}
