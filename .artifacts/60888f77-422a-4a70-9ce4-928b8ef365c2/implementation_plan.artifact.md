# Implementation Plan - Revert UI Additions and Enable Night Mode

Revert recent UI changes (Category Chips and Quick Prompts) and implement a modern Dark Mode for the ITI Project application.

## User Review Required

> [!IMPORTANT]
> - The Category Chips and Quick Prompts were not found in the current source code. I will ensure they are not present and focus on the Dark Mode implementation.
> - The application currently uses OpenAI for the AI Assistant; this will be preserved as per the "active implementation" instruction.

## Proposed Changes

### Core UI & Theming

#### [MODIFY] [main.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/main.dart)
- Set `themeMode` to `ThemeMode.dark`.
- Configure `darkTheme` with `ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark)`.
- Enable `useMaterial3: true`.

### Home Feature

#### [MODIFY] [home_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/home/presentation/screens/home_screen.dart)
- Verify and ensure no Category Chips are present. (Already appears clean).

#### [MODIFY] [person_provider.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/home/presentation/providers/person_provider.dart)
- Verify and ensure no category filtering logic is present. (Already appears clean).

### AI Assistant Feature

#### [MODIFY] [chat_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/ai_assistant/presentation/screens/chat_screen.dart)
- Verify and ensure no Quick Prompts are present. (Already appears clean).

## Verification Plan

### Manual Verification
- Launch the application and verify that the UI is in Dark Mode (Night Mode).
- Verify that the Home screen shows the popular persons grid without any category chips.
- Verify that the Chat screen is clean, without quick prompts.
- Ensure the AI Assistant still functions correctly using the OpenAI backend.
- Check navigation to Details, Favorites, and Chat to ensure consistent dark theme application.
