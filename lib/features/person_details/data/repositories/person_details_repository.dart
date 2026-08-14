import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itiproject/core/constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/person_details_model.dart';
import '../models/person_image_model.dart';

final personDetailsRepositoryProvider = Provider<PersonDetailsRepository>((
  ref,
) {
  return PersonDetailsRepository(ref.watch(dioProvider));
});

class PersonDetailsRepository {
  final Dio _dio;

  PersonDetailsRepository(this._dio);

  Future<PersonDetails> getPersonDetails(int id) async {
    try {
      final response = await _dio.get('/person/$id');
      final details = PersonDetails.fromJson(response.data);

      if (details.biography == null || details.biography!.trim().isEmpty) {
        final aiBio = await getAIBiography(details.name);
        return details.copyWith(biography: aiBio);
      }

      return details;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getAIBiography(String name) async {
    try {
      final response = await _dio.post(
        '${AppConstants.groqBaseUrl}/chat/completions',
        data: {
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "system",
              "content":
                  "You are a professional biographer. Write a concise, family-friendly 3-sentence biography for the given celebrity. Avoid controversial topics.",
            },
            {"role": "user", "content": "Write a biography for $name"},
          ],
        },
        options: Options(
          headers: {
            "Authorization": "Bearer ${AppConstants.groqApiKey}",
            "Content-Type": "application/json",
          },
        ),
      );

      return response.data['choices'][0]['message']['content'] ??
          'Biography coming soon';
    } catch (e) {
      return 'Biography coming soon';
    }
  }

  Future<List<PersonImage>> getPersonImages(int id) async {
    try {
      final response = await _dio.get('/person/$id/images');
      return PersonImages.fromJson(response.data).profiles;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getPersonCredits(int id) async {
    try {
      final response = await _dio.get('/person/$id/combined_credits');
      final List cast = response.data['cast'] ?? [];

      cast.sort(
        (a, b) => (b['popularity'] ?? 0).compareTo(a['popularity'] ?? 0),
      );
      return cast
          .take(5)
          .map((e) => (e['title'] ?? e['name'] ?? 'Unknown Work') as String)
          .toList();
    } catch (e) {
      return [];
    }
  }
}
