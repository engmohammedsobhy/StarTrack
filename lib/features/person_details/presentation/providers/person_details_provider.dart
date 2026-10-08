import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itiproject/features/home/data/repositories/knowledge_repository.dart';

import 'package:itiproject/features/home/data/models/entity_model.dart';
import '../../data/models/rag_response_model.dart';
export 'rag_provider.dart';

final entityBiographyProvider = FutureProvider.family<String, String>((
  ref,
  title,
) async {
  final repository = ref.watch(knowledgeRepositoryProvider);
  return repository.getEntityBiography(title);
});

final entityGalleryProvider = FutureProvider.family<List<String>, String>((
  ref,
  title,
) async {
  final repository = ref.watch(knowledgeRepositoryProvider);
  return repository.getEntityGallery(title);
});

final aiOverviewProvider = FutureProvider.family<String, String>((ref, bio) async {
  final repository = ref.watch(knowledgeRepositoryProvider);
  return repository.getAIOverview(bio);
});

final ragOverviewProvider = FutureProvider.family<RagQueryResponse, String>((ref, title) {
  return ref.read(knowledgeRepositoryProvider).getRagOverview(title);
});

class EntityRecommendationsNotifier extends FamilyAsyncNotifier<List<KnowledgeEntity>, String> {
  bool _isFetching = false;

  @override
  FutureOr<List<KnowledgeEntity>> build(String arg) async {
    return await ref.read(knowledgeRepositoryProvider).getRecommendations([arg], limit: 6);
  }

  Future<void> fetchMore() async {
    if (_isFetching) return;
    final currentList = state.value ?? [];
    if (currentList.isEmpty) return;

    _isFetching = true;
    try {
      final currentTitles = currentList.map((e) => e.title).toList();
      final newEntities = await ref.read(knowledgeRepositoryProvider).getRecommendations(
        [arg, ...currentTitles],
        limit: 6,
      );
      final existingIds = currentList.map((e) => e.id).toSet();
      final uniqueNew = newEntities.where((e) => !existingIds.contains(e.id)).toList();
      state = AsyncData([...currentList, ...uniqueNew]);
    } catch (e) {
      // Handle error gracefully
    } finally {
      _isFetching = false;
    }
  }
}

final entityRecommendationsNotifierProvider = AsyncNotifierProvider.family<EntityRecommendationsNotifier, List<KnowledgeEntity>, String>(EntityRecommendationsNotifier.new);
