import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itiproject/features/home/data/repositories/knowledge_repository.dart';
import '../../data/models/rag_response_model.dart';

final ragOverviewProvider = FutureProvider.family<RagQueryResponse, String>((ref, title) {
  return ref.read(knowledgeRepositoryProvider).getRagOverview(title);
});
