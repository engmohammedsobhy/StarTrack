import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/person_model.dart';
import '../../data/repositories/person_repository.dart';

final popularPersonsProvider = FutureProvider.autoDispose<List<Person>>((
  ref,
) async {
  return ref.read(personRepositoryProvider).getPopularPersons();
});
