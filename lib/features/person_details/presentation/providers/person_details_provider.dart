import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/person_details_model.dart';
import '../../data/models/person_image_model.dart';
import '../../data/repositories/person_details_repository.dart';

final personDetailsProvider = FutureProvider.family<PersonDetails, int>((
  ref,
  id,
) async {
  final repository = ref.watch(personDetailsRepositoryProvider);
  return repository.getPersonDetails(id);
});

final personImagesProvider = FutureProvider.family<List<PersonImage>, int>((
  ref,
  id,
) async {
  final repository = ref.watch(personDetailsRepositoryProvider);
  return repository.getPersonImages(id);
});

final personCreditsProvider = FutureProvider.family<List<String>, int>((
  ref,
  id,
) async {
  final repository = ref.watch(personDetailsRepositoryProvider);
  return repository.getPersonCredits(id);
});
