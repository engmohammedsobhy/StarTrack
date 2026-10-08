import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/entity_model.dart';
import '../../data/repositories/knowledge_repository.dart';
import '../../../favorites/presentation/providers/favorites_provider.dart';

class UserInterestsState {
  final List<String> recentSearches;
  final List<KnowledgeEntity> viewedPersonas;

  const UserInterestsState({
    this.recentSearches = const [],
    this.viewedPersonas = const [],
  });

  UserInterestsState copyWith({
    List<String>? recentSearches,
    List<KnowledgeEntity>? viewedPersonas,
  }) {
    return UserInterestsState(
      recentSearches: recentSearches ?? this.recentSearches,
      viewedPersonas: viewedPersonas ?? this.viewedPersonas,
    );
  }
}

class UserInterestsNotifier extends Notifier<UserInterestsState> {
  static const _searchKey = 'persona_recent_searches_v1';
  static const _viewedKey = 'persona_viewed_history_v1';

  @override
  UserInterestsState build() {
    _loadState();
    return const UserInterestsState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searches = prefs.getStringList(_searchKey) ?? [];

      final viewedRaw = prefs.getStringList(_viewedKey) ?? [];
      final List<KnowledgeEntity> viewedList = [];
      for (final raw in viewedRaw) {
        try {
          final map = json.decode(raw) as Map<String, dynamic>;
          viewedList.add(KnowledgeEntity.fromJson(map));
        } catch (_) {}
      }

      state = UserInterestsState(
        recentSearches: searches,
        viewedPersonas: viewedList,
      );
    } catch (_) {}
  }

  Future<void> addSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final updated = List<String>.from(state.recentSearches);
    updated.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
    updated.insert(0, clean);

    if (updated.length > 20) {
      updated.removeRange(20, updated.length);
    }

    state = state.copyWith(recentSearches: updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_searchKey, updated);
    } catch (_) {}
  }

  Future<void> removeSearch(String query) async {
    final updated = List<String>.from(state.recentSearches)
      ..removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
    state = state.copyWith(recentSearches: updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_searchKey, updated);
    } catch (_) {}
  }

  Future<void> clearSearches() async {
    state = state.copyWith(recentSearches: []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchKey);
    } catch (_) {}
  }

  Future<void> recordViewedPersona(KnowledgeEntity entity) async {
    if (entity.title.trim().isEmpty) return;

    final updated = List<KnowledgeEntity>.from(state.viewedPersonas);
    updated.removeWhere((e) =>
        e.id == entity.id || e.title.toLowerCase() == entity.title.toLowerCase());
    updated.insert(0, entity);

    if (updated.length > 25) {
      updated.removeRange(25, updated.length);
    }

    state = state.copyWith(viewedPersonas: updated);

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = updated.map((e) => json.encode(e.toJson())).toList();
      await prefs.setStringList(_viewedKey, rawList);
    } catch (_) {}
  }

  Future<void> clearViewedPersonas() async {
    state = state.copyWith(viewedPersonas: []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_viewedKey);
    } catch (_) {}
  }
}

final userInterestsProvider =
    NotifierProvider<UserInterestsNotifier, UserInterestsState>(
  UserInterestsNotifier.new,
);

/// Model for dynamic curated recommendation sections in Search & Home
class DynamicCuratedSection {
  final String title;
  final String? subtitle;
  final String? sourcePersona;
  final List<KnowledgeEntity> entities;

  const DynamicCuratedSection({
    required this.title,
    this.subtitle,
    this.sourcePersona,
    required this.entities,
  });
}

/// Provider that generates personalized curated sections based on user's loves, views, and searches
final dynamicPersonalizedSectionsProvider =
    FutureProvider<List<DynamicCuratedSection>>((ref) async {
  final favorites = ref.watch(favoritesProvider);
  final interests = ref.watch(userInterestsProvider);
  final repo = ref.watch(knowledgeRepositoryProvider);

  final List<DynamicCuratedSection> sections = [];
  final Set<String> seenEntityTitles = {};

  // 1. If user has favorites / loves: generate high-affinity recommendations
  if (favorites.isNotEmpty) {
    final topLoved = favorites.take(2).toList();
    for (final fav in topLoved) {
      try {
        final recs = await repo.getRecommendations(
          [fav.title],
          limit: 6,
        );
        final filtered = recs
            .where((e) =>
                e.title.toLowerCase() != fav.title.toLowerCase() &&
                !seenEntityTitles.contains(e.title.toLowerCase()))
            .toList();

        if (filtered.isNotEmpty) {
          for (final e in filtered) {
            seenEntityTitles.add(e.title.toLowerCase());
          }
          sections.add(
            DynamicCuratedSection(
              title: 'Because You Love ${fav.title}',
              subtitle: 'Tailored to your favorite persona',
              sourcePersona: fav.title,
              entities: filtered,
            ),
          );
        }
      } catch (_) {}
    }
  }

  // 2. If user has viewed personas: generate "Because you explored..."
  if (interests.viewedPersonas.isNotEmpty) {
    final recentlyViewed = interests.viewedPersonas.first;
    // Don't repeat if it's already top loved
    final isAlreadyLoved = favorites.any((f) => f.title.toLowerCase() == recentlyViewed.title.toLowerCase());
    if (!isAlreadyLoved) {
      try {
        final recs = await repo.getRecommendations(
          [],
          viewedPersonas: [recentlyViewed.title],
          limit: 6,
        );
        final filtered = recs
            .where((e) =>
                e.title.toLowerCase() != recentlyViewed.title.toLowerCase() &&
                !seenEntityTitles.contains(e.title.toLowerCase()))
            .toList();

        if (filtered.isNotEmpty) {
          for (final e in filtered) {
            seenEntityTitles.add(e.title.toLowerCase());
          }
          sections.add(
            DynamicCuratedSection(
              title: 'Because You Explored ${recentlyViewed.title}',
              subtitle: 'Deep dives related to your recent visit',
              sourcePersona: recentlyViewed.title,
              entities: filtered,
            ),
          );
        }
      } catch (_) {}
    }
  }

  // 3. If user has recent searches: generate "Based On Your Search '...'"
  if (interests.recentSearches.isNotEmpty) {
    final topQuery = interests.recentSearches.first;
    try {
      final searchRecs = await repo.searchEntities(topQuery);
      final filtered = searchRecs
          .where((e) => !seenEntityTitles.contains(e.title.toLowerCase()))
          .take(6)
          .toList();

      if (filtered.isNotEmpty) {
        for (final e in filtered) {
          seenEntityTitles.add(e.title.toLowerCase());
        }
        sections.add(
          DynamicCuratedSection(
            title: 'Based On Your Search for "$topQuery"',
            subtitle: 'Icons matching your recent curiosity',
            sourcePersona: topQuery,
            entities: filtered,
          ),
        );
      }
    } catch (_) {}
  }

  // 4. If fewer than 2 sections exist, fill in with dynamic starter categories
  if (sections.length < 2) {
    const starterCategories = [
      {
        'title': 'Trending Visionaries',
        'personas': ['Nikola Tesla', 'Albert Einstein', 'Marie Curie', 'Steve Jobs', 'Alan Turing'],
      },
      {
        'title': 'Iconic Cultural Figures',
        'personas': ['Leonardo da Vinci', 'Pablo Picasso', 'William Shakespeare', 'Charlie Chaplin', 'Marilyn Monroe'],
      },
      {
        'title': 'World Champions',
        'personas': ['Lionel Messi', 'Cristiano Ronaldo', 'Muhammad Ali', 'Michael Jordan', 'Tom Brady'],
      },
    ];

    for (final cat in starterCategories) {
      if (sections.length >= 3) break;
      final names = cat['personas'] as List<String>;
      final List<KnowledgeEntity> starterEntities = [];
      for (final name in names) {
        if (!seenEntityTitles.contains(name.toLowerCase())) {
          seenEntityTitles.add(name.toLowerCase());
          starterEntities.add(
            KnowledgeEntity(
              id: name,
              title: name,
              description: 'Notable icon',
            ),
          );
        }
      }
      if (starterEntities.isNotEmpty) {
        sections.add(
          DynamicCuratedSection(
            title: cat['title'] as String,
            subtitle: 'Curated for you',
            entities: starterEntities,
          ),
        );
      }
    }
  }

  return sections;
});
