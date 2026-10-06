import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final Dio _dio = Dio();

  ChatNotifier() : super(const AsyncData([]));

  Future<void> sendMessage(
    String text, {
    String? entityName,
    String? entityTitle,
  }) async {
    final currentMessages = state.value ?? [];
    final userMessage = ChatMessage(text: text, isUser: true);

    state = AsyncData([...currentMessages, userMessage]);
    state = const AsyncLoading<List<ChatMessage>>().copyWithPrevious(state);

    if (entityName != null &&
        entityName.isNotEmpty &&
        entityTitle != null &&
        entityTitle.isNotEmpty) {
      try {
        final response = await _dio.post(
          '${AppConstants.ragBackendUrl}/api/v1/rag/query',
          data: {
            "entity_name": entityName,
            "wikipedia_title": entityTitle,
            "user_query": text,
            "top_k": 3,
          },
          options: Options(
            headers: {"Content-Type": "application/json"},
            receiveTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 15),
          ),
        );

        final aiResponse = response.data['answer'] as String;

        final botMessage = ChatMessage(text: aiResponse, isUser: false);
        state = AsyncData([...state.value!, botMessage]);
        return; // Success, skip fallback
      } catch (_) {
        // Fallback to Groq API on any error (e.g., backend not running)
      }
    }

    String systemPrompt =
        "You are a helpful and family-friendly celebrity assistant. You provide information about actors and singers. You must ensure all responses are appropriate for all ages and avoid any adult, offensive, or controversial content.";
    if (entityName != null && entityName.isNotEmpty) {
      systemPrompt += "\n\nThe user is asking about $entityName.";
    }

    try {
      final messages = [
        {"role": "system", "content": systemPrompt},
        ...currentMessages.map(
          (m) => {"role": m.isUser ? "user" : "assistant", "content": m.text},
        ),
        {"role": "user", "content": text},
      ];

      final response = await _dio.post(
        '${AppConstants.groqBaseUrl}/chat/completions',
        data: {"model": "openai/gpt-oss-120b", "messages": messages},
        options: Options(
          headers: {
            "Authorization": "Bearer ${AppConstants.groqApiKey}",
            "Content-Type": "application/json",
          },
        ),
      );

      final botResponse =
          response.data['choices'][0]['message']['content'] ?? 'No response';
      final botMessage = ChatMessage(text: botResponse, isUser: false);
      state = AsyncData([...state.value!, botMessage]);
    } on DioException catch (e, stack) {
      _handleDioError(e, stack);
    } catch (e, stack) {
      state = AsyncError('AI Assistant error: ${e.toString()}', stack);
    }
  }

  void _handleDioError(DioException e, StackTrace stack) {
    String responseBody = e.response?.data?.toString() ?? "";
    String errorMessage = 'Service connection issue';

    if (responseBody.contains('<!DOCTYPE html>') ||
        responseBody.toLowerCase().contains('<html>')) {
      errorMessage = 'Service connection issue';
    } else {
      final errorData = e.response?.data;
      if (errorData is Map && errorData.containsKey('error')) {
        errorMessage = 'Groq Error: ${errorData['error']['message']}';
      } else {
        errorMessage = 'AI Assistant error: ${e.message}';
      }
    }

    state = AsyncError(errorMessage, stack);
  }
}

final chatProvider =
    StateNotifierProvider<ChatNotifier, AsyncValue<List<ChatMessage>>>((ref) {
      return ChatNotifier();
    });
