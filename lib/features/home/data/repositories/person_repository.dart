import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itiproject/core/network/dio_client.dart';
import '../models/person_model.dart';

final personRepositoryProvider = Provider<PersonRepository>((ref) {
  return PersonRepository(ref.watch(dioProvider));
});

class PersonRepository {
  final Dio _dio;

  PersonRepository(this._dio);

  Future<List<Person>> getPopularPersons() async {
    try {
      List<Person> allPersons = [];

      for (int i = 1; i <= 2; i++) {
        final response = await _dio.get(
          '/person/popular',
          queryParameters: {'page': i},
        );
        if (response.statusCode == 200) {
          final List results = response.data['results'];
          allPersons.addAll(results.map((e) => Person.fromJson(e)).toList());
        }
      }

      final legends = [
        'Drake',
        'The Weeknd',
        'Justin Bieber',
        'Taylor Swift',
        'Michael Jackson',
        'Beyoncé',
      ];
      final List<Future<Response>> searchTasks = [];
      for (final legend in legends) {
        if (!allPersons.any(
          (p) => p.name.toLowerCase().contains(legend.toLowerCase()),
        )) {
          searchTasks.add(
            _dio.get('/search/person', queryParameters: {'query': legend}),
          );
        }
      }

      final searchResponses = await Future.wait(searchTasks);
      for (final response in searchResponses) {
        if (response.statusCode == 200) {
          final List results = response.data['results'];
          if (results.isNotEmpty) {
            allPersons.add(Person.fromJson(results.first));
          }
        }
      }

      final topPersons = allPersons.take(30).toList();

      final List<Person> filteredPersons = [];

      final List<Future<void>> filterTasks = topPersons.map((person) async {
        try {
          final detailsResponse = await _dio.get('/person/${person.id}');
          final imagesResponse = await _dio.get('/person/${person.id}/images');

          if (detailsResponse.statusCode == 200 &&
              imagesResponse.statusCode == 200) {
            final profiles = imagesResponse.data['profiles'] as List?;
            final imageCount = profiles?.length ?? 0;

            if (imageCount > 1) {
              final isAdult = detailsResponse.data['adult'] as bool? ?? false;
              if (!isAdult) {
                filteredPersons.add(person);
              }
            }
          }
        } catch (e) {}
      }).toList();

      await Future.wait(filterTasks);

      final Map<int, Person> uniquePersons = {};
      for (var p in filteredPersons) {
        uniquePersons[p.id] = p;
      }

      return uniquePersons.values.toList();
    } catch (e) {
      throw Exception('Error fetching persons: $e');
    }
  }
}
