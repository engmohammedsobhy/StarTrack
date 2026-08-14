# Implementation Plan - Robust AI Fallback with Gemini Multi-Model Support

Diagnose and improve the AI fallback logic in `ChatNotifier` to handle failures from both OpenAI and Gemini more gracefully.

## User Review Required

> [!IMPORTANT]
> The Gemini API key in `lib/core/constants.dart` (`AQ.Ab8RN6...`) does not match the standard `AIza...` format. This is likely the primary cause of Gemini failures. Please verify this key.

## Proposed Changes

### `lib/features/ai_assistant/presentation/providers/chat_provider.dart`

- [MODIFY] [chat_provider.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/ai_assistant/presentation/providers/chat_provider.dart)
    - Update `_sendGeminiRequest` to accept a `modelName` parameter.
    - Update `sendMessage` logic to iterate through multiple Gemini models (`gemini-1.5-flash`, `gemini-1.5-pro`, `gemini-pro`) if OpenAI fails (status 401, 402, 429).
    - Enhance error reporting to include specific details from both providers in the final `AsyncError` state.

## Verification Plan

### Manual Verification
- Trigger an OpenAI failure (e.g. by temporarily changing the API key) and verify that the app attempts multiple Gemini models.
- Verify that if both providers fail, the UI shows a detailed error message containing both OpenAI and Gemini error descriptions.
