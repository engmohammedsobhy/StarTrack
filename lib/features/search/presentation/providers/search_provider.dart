import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';
import 'package:itiproject/features/home/data/repositories/knowledge_repository.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final selectedFilterChipProvider = StateProvider<String>((ref) => 'All');

final searchResultsProvider = FutureProvider<List<KnowledgeEntity>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();

  if (query.isEmpty) {
    return [];
  }

  // Add debounce
  await Future.delayed(const Duration(milliseconds: 400));

  final repository = ref.read(knowledgeRepositoryProvider);
  return repository.searchEntities(query);
});

final curatedCategorySectionProvider = FutureProvider.family<List<KnowledgeEntity>, List<String>>((ref, names) async {
  final repository = ref.read(knowledgeRepositoryProvider);
  final List<KnowledgeEntity> entities = [];

  for (final name in names) {
    try {
      final list = await repository.searchEntities(name);
      if (list.isNotEmpty) {
        entities.add(list.first);
      }
    } catch (_) {}
  }

  return entities;
});

final searchTrendingGridProvider = FutureProvider<List<KnowledgeEntity>>((ref) async {
  final filter = ref.watch(selectedFilterChipProvider);
  final repository = ref.read(knowledgeRepositoryProvider);

  if (filter == 'All') {
    return repository.getTrendingEntities(page: 1, refresh: true);
  }

  final String queryTerm;
  switch (filter) {
    case 'Actors':
      queryTerm = 'Famous Hollywood actors';
      break;
    case 'Musicians':
      queryTerm = 'Famous singers musicians';
      break;
    case 'Scientists':
      queryTerm = 'Famous scientific geniuses physicists';
      break;
    case 'Athletes':
      queryTerm = 'Famous athletes football basketball';
      break;
    case 'Philosophers':
      queryTerm = 'Famous ancient modern philosophers';
      break;
    case 'Historians':
      queryTerm = 'Famous historians world leaders';
      break;
    default:
      queryTerm = filter;
  }

  return repository.searchEntities(queryTerm);
});
