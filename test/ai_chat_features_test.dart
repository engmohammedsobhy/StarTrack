import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:itiproject/features/ai_assistant/presentation/providers/chat_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ChatMessage & ChatSession Model Tests', () {
    test('ChatMessage serializes and deserializes properly with mentionedPersona', () {
      final msg = ChatMessage(
        id: 'msg_1',
        text: 'Tell me about @Lionel Messi',
        isUser: true,
        timestamp: DateTime(2026, 10, 8, 10, 0),
        mentionedPersona: 'Lionel Messi',
      );

      final json = msg.toJson();
      expect(json['id'], 'msg_1');
      expect(json['text'], 'Tell me about @Lionel Messi');
      expect(json['isUser'], true);
      expect(json['mentionedPersona'], 'Lionel Messi');

      final fromJson = ChatMessage.fromJson(json);
      expect(fromJson.id, msg.id);
      expect(fromJson.text, msg.text);
      expect(fromJson.isUser, msg.isUser);
      expect(fromJson.mentionedPersona, 'Lionel Messi');
    });

    test('ChatSession roundtrip serialization', () {
      final session = ChatSession(
        id: 'session_123',
        title: 'Chat with @Ada Lovelace',
        createdAt: DateTime(2026, 10, 8, 10, 30),
        personaName: 'Ada Lovelace',
        messages: [
          ChatMessage(
            id: 'm1',
            text: '@Ada Lovelace',
            isUser: true,
            timestamp: DateTime(2026, 10, 8, 10, 30),
            mentionedPersona: 'Ada Lovelace',
          ),
          ChatMessage(
            id: 'm2',
            text: 'Ada Lovelace was an English mathematician...',
            isUser: false,
            timestamp: DateTime(2026, 10, 8, 10, 31),
          ),
        ],
      );

      final json = session.toJson();
      final restored = ChatSession.fromJson(json);

      expect(restored.id, 'session_123');
      expect(restored.title, 'Chat with @Ada Lovelace');
      expect(restored.personaName, 'Ada Lovelace');
      expect(restored.messages.length, 2);
      expect(restored.messages.first.mentionedPersona, 'Ada Lovelace');
      expect(restored.messages.last.isUser, false);
    });
  });

  group('Persona Mention Suggestions Provider Tests', () {
    test('personaMentionSuggestionsProvider filters matching personas for query', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Search for "messi"
      final suggestions = await container.read(personaMentionSuggestionsProvider('messi').future);
      expect(suggestions.any((p) => p.title.toLowerCase().contains('messi')), true);
    });

    test('personaMentionSuggestionsProvider returns default recommendations for empty query', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final suggestions = await container.read(personaMentionSuggestionsProvider('').future);
      expect(suggestions.isNotEmpty, true);
    });
  });

  group('ChatNotifier Session Management Tests', () {
    test('startNewChat clears active messages and active session ID', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(chatProvider.notifier);
      notifier.startNewChat();

      final state = container.read(chatProvider);
      expect(state.value, isEmpty);
      expect(notifier.activeSessionId, isNotNull);
    });
  });
}
