import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../home/data/models/entity_model.dart';

class FavoritesNotifier extends Notifier<List<KnowledgeEntity>> {
  static const _key = 'favorites';

  @override
  List<KnowledgeEntity> build() {
    _loadFavorites();
    return [];
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_key) ?? [];
    state = jsonList
        .map((e) => KnowledgeEntity.fromJson(json.decode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> toggleFavorite(KnowledgeEntity entity) async {
    final isFavorite = state.any((e) => e.id == entity.id);
    if (isFavorite) {
      state = state.where((e) => e.id != entity.id).toList();
    } else {
      state = [...state, entity];
    }

    await _saveFavorites();
  }

  Future<void> clearAll() async {
    state = [];
    await _saveFavorites();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = state.map((e) => json.encode(e.toJson())).toList();
    await prefs.setStringList(_key, jsonList);
  }

  bool isFavorite(String id) {
    return state.any((e) => e.id == id);
  }
}

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<KnowledgeEntity>>(
  FavoritesNotifier.new,
);
