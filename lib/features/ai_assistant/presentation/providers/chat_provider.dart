import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants.dart';
import '../../../home/data/models/entity_model.dart';
import '../../../home/data/repositories/knowledge_repository.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? mentionedPersona;

  ChatMessage({
    String? id,
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.mentionedPersona,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      text: json['text'] as String? ?? '',
      isUser: json['isUser'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      mentionedPersona: json['mentionedPersona'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      if (mentionedPersona != null) 'mentionedPersona': mentionedPersona,
    };
  }
}

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<ChatMessage> messages;
  final String? personaName;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.messages,
    this.personaName,
  });

  factory ChatSession.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'] as List<dynamic>? ?? [];
    return ChatSession(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'New Chat',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      personaName: json['personaName'] as String?,
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map((m) => ChatMessage.fromJson(m))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      if (personaName != null) 'personaName': personaName,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

class ChatNotifier extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  final Dio _dio = Dio();
  static const _historyKey = 'persona_ai_chat_sessions_v2';

  List<ChatSession> _sessions = [];
  String? _activeSessionId;

  List<ChatSession> get sessions => List.unmodifiable(_sessions);
  String? get activeSessionId => _activeSessionId;

  ChatNotifier() : super(const AsyncData([])) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_historyKey) ?? [];
      _sessions = rawList
          .map((s) {
            try {
              return ChatSession.fromJson(json.decode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<ChatSession>()
          .toList();

      // Sort sessions newest first
      _sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      _sessions = [];
    }
  }

  Future<void> _persistHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = _sessions.map((s) => json.encode(s.toJson())).toList();
      await prefs.setStringList(_historyKey, rawList);
    } catch (_) {}
  }

  void startNewChat({KnowledgeEntity? entity}) {
    _activeSessionId = DateTime.now().millisecondsSinceEpoch.toString();
    state = const AsyncData([]);

    if (entity != null) {
      sendMessage(
        "Who is ${entity.title}?",
        entityName: entity.title,
        entityTitle: entity.title,
      );
    }
  }

  void loadSession(String sessionId) {
    final session = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => ChatSession(
        id: sessionId,
        title: 'Chat',
        createdAt: DateTime.now(),
        messages: [],
      ),
    );

    _activeSessionId = session.id;
    state = AsyncData(List<ChatMessage>.from(session.messages));
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    await _persistHistory();

    if (_activeSessionId == sessionId) {
      startNewChat();
    }
  }

  Future<void> clearAllHistory() async {
    _sessions.clear();
    await _persistHistory();
    startNewChat();
  }

  /// Parses mentions like @Lionel Messi or @Cillian Murphy from input
  String? _extractMention(String text) {
    final match = RegExp(r'@([A-Za-z0-9\s\.\-]{2,30})').firstMatch(text);
    if (match != null) {
      final captured = match.group(1)?.trim();
      if (captured != null && captured.isNotEmpty) {
        // Strip trailing query punctuation
        return captured.replaceAll(RegExp(r'[?!.,;]+$'), '').trim();
      }
    }
    return null;
  }

  Future<void> sendMessage(
    String rawText, {
    String? entityName,
    String? entityTitle,
  }) async {
    final currentMessages = state.value ?? [];
    final text = rawText.trim();
    if (text.isEmpty) return;

    // Detect @mention in text
    final mention = _extractMention(text);
    final effectivePersona = entityName ?? mention;

    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      mentionedPersona: effectivePersona,
    );

    state = AsyncData([...currentMessages, userMessage]);
    state = const AsyncLoading<List<ChatMessage>>().copyWithPrevious(state);

    // Initialize session ID if not active
    _activeSessionId ??= DateTime.now().millisecondsSinceEpoch.toString();

    // Check if user simply typed @Persona or @PersonaName
    final bool isPureMention = text.startsWith('@') &&
        (text.length <= (mention?.length ?? 0) + 3);

    String queryForAi = text;
    if (isPureMention && effectivePersona != null) {
      queryForAi =
          "Tell me about $effectivePersona — who they are, their greatest achievements, signature traits, and what makes them iconic. Then ask me what aspects I'd like to explore next about them.";
    }

    // 1. Try Backend RAG query if asking about a specific persona
    if (effectivePersona != null && effectivePersona.isNotEmpty) {
      try {
        Response? response;
        final ragPayload = {
          "entity_name": effectivePersona,
          "wikipedia_title": entityTitle ?? effectivePersona,
          "user_query": queryForAi,
          "top_k": 3,
        };

        try {
          response = await _dio.post(
            '${AppConstants.ragBackendUrl}/api/v1/rag/query',
            data: ragPayload,
            options: Options(
              headers: {"Content-Type": "application/json"},
              receiveTimeout: const Duration(seconds: 25),
              sendTimeout: const Duration(seconds: 25),
            ),
          );
        } catch (_) {
          try {
            response = await _dio.post(
              'http://localhost:8000/api/v1/rag/query',
              data: ragPayload,
              options: Options(
                headers: {"Content-Type": "application/json"},
                receiveTimeout: const Duration(seconds: 25),
                sendTimeout: const Duration(seconds: 25),
              ),
            );
          } catch (_) {
            response = null;
          }
        }

        if (response != null && response.statusCode == 200 && response.data != null) {
          final aiResponse = response.data['answer'] as String;
          final botMessage = ChatMessage(
            text: aiResponse,
            isUser: false,
            mentionedPersona: effectivePersona,
          );
          final updated = [...state.value!, botMessage];
          state = AsyncData(updated);
          _saveCurrentSession(updated, personaName: effectivePersona);
          return;
        }
      } catch (_) {
        // Fallback to Groq API with enhanced system prompt
      }
    }

    // 2. Enhanced System Prompt
    String systemPrompt =
        "You are StarTrack Persona AI — a brilliant, charismatic, and authoritative biographical intelligence assistant.\n"
        "You possess encyclopedic knowledge about notable figures, celebrities, iconic athletes, historical titans, artists, scientists, and legendary fictional characters.\n\n"
        "CRITICAL DIRECTIVES:\n"
        "1. When asked about any persona (or when the user mentions @PersonaName):\n"
        "   - Deliver a captivating, vivid, and authoritative synthesis: who they are, their crowning achievements, and their enduring legacy.\n"
        "   - Use clean, modern Markdown with bold highlights and clean paragraphs.\n"
        "   - PROACTIVE ENGAGEMENT: Conclude your answer by warmly asking the user what specific aspects they want to discover next (e.g., career milestones, early beginnings, major awards, or intriguing trivia).\n"
        "2. If the user only typed an @mention like '@Lionel Messi', give an inspiring introduction and proactively invite them to explore specific dimensions.\n"
        "3. Keep all responses engaging, respectful, informative, and suitable for all audiences.";

    if (effectivePersona != null && effectivePersona.isNotEmpty) {
      systemPrompt +=
          "\n\n[Active Focus]: The user is inquiring about '$effectivePersona'. Focus on their story, accomplishments, and distinct character.";
    }

    try {
      final messages = [
        {"role": "system", "content": systemPrompt},
        ...currentMessages.map(
          (m) => {"role": m.isUser ? "user" : "assistant", "content": m.text},
        ),
        {"role": "user", "content": queryForAi},
      ];

      final response = await _dio.post(
        '${AppConstants.groqBaseUrl}/chat/completions',
        data: {
          "model": "openai/gpt-oss-120b",
          "messages": messages,
          "temperature": 0.3,
          "max_tokens": 1200,
        },
        options: Options(
          headers: {
            "Authorization": "Bearer ${AppConstants.groqApiKey}",
            "Content-Type": "application/json",
          },
        ),
      );

      final botResponse =
          response.data['choices'][0]['message']['content'] ??
          "I'm here to help you explore any persona! Tell me who you'd like to learn about.";
      final botMessage = ChatMessage(
        text: botResponse,
        isUser: false,
        mentionedPersona: effectivePersona,
      );
      final updated = [...state.value!, botMessage];
      state = AsyncData(updated);
      _saveCurrentSession(updated, personaName: effectivePersona);
    } on DioException catch (e, stack) {
      _handleDioError(e, stack);
    } catch (e, stack) {
      state = AsyncError('AI Assistant error: ${e.toString()}', stack);
    }
  }

  void _saveCurrentSession(List<ChatMessage> messages, {String? personaName}) {
    if (messages.isEmpty) return;

    final firstUserMsg = messages.firstWhere(
      (m) => m.isUser,
      orElse: () => messages.first,
    );

    String title = personaName != null
        ? 'About $personaName'
        : firstUserMsg.text;
    if (title.length > 36) {
      title = '${title.substring(0, 33)}...';
    }

    final existingIndex = _sessions.indexWhere((s) => s.id == _activeSessionId);
    final updatedSession = ChatSession(
      id: _activeSessionId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: existingIndex >= 0
          ? _sessions[existingIndex].createdAt
          : DateTime.now(),
      messages: List<ChatMessage>.from(messages),
      personaName: personaName,
    );

    if (existingIndex >= 0) {
      _sessions[existingIndex] = updatedSession;
    } else {
      _sessions.insert(0, updatedSession);
    }

    _persistHistory();
  }

  void _handleDioError(DioException e, StackTrace stack) {
    String responseBody = e.response?.data?.toString() ?? "";
    String errorMessage = 'Service connection issue';

    if (responseBody.contains('<!DOCTYPE html>') ||
        responseBody.toLowerCase().contains('<html>')) {
      errorMessage = 'Service connection issue. Please check your network and try again.';
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

/// Fast provider for @mention persona autocomplete
final personaMentionSuggestionsProvider =
    FutureProvider.family<List<KnowledgeEntity>, String>((ref, query) async {
  final cleanQuery = query.toLowerCase().trim();
  final repo = ref.read(knowledgeRepositoryProvider);

  // Pool of top iconic personas for instant WhatsApp-style mention suggestions
  final pool = KnowledgeRepository.defaultPersonaPool;

  final matchingNames = cleanQuery.isEmpty
      ? pool.take(8).toList()
      : pool.where((name) => name.toLowerCase().contains(cleanQuery)).take(8).toList();

  final List<KnowledgeEntity> results = [];
  for (final name in matchingNames) {
    results.add(
      KnowledgeEntity(
        id: name,
        title: name,
        description: 'Notable persona',
      ),
    );
  }

  // If query has characters and pool results are sparse, search via repository
  if (cleanQuery.length >= 2 && results.length < 4) {
    try {
      final searchResults = await repo.searchEntities(cleanQuery);
      for (final entity in searchResults) {
        if (!results.any((e) => e.title.toLowerCase() == entity.title.toLowerCase())) {
          results.add(entity);
        }
        if (results.length >= 8) break;
      }
    } catch (_) {}
  }

  return results;
});
