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

  Future<void> sendMessage(String text) async {
    final currentMessages = state.value ?? [];
    final userMessage = ChatMessage(text: text, isUser: true);

    state = AsyncData([...currentMessages, userMessage]);
    state = const AsyncLoading<List<ChatMessage>>().copyWithPrevious(state);

    const systemPrompt =
        "You are a helpful and family-friendly celebrity assistant. You provide information about actors and singers. You must ensure all responses are appropriate for all ages and avoid any adult, offensive, or controversial content.";

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
        data: {"model": "llama-3.3-70b-versatile", "messages": messages},
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
