# Implementation Plan - Reverting UI/UX and Logic Overhaul

The goal is to revert the "Premium UI/UX" overhaul and return the application to a stable, simpler state as requested. This involves simplifying the Home, Details, and Chat screens, and ensuring no AI logic is present in the repositories for biographies.

## Proposed Changes

### [Home Feature](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/home)

#### [MODIFY] [home_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/home/presentation/screens/home_screen.dart)
- The current implementation already uses `GridView.builder` and lacks category chips. I will verify that no hidden filtering logic or complex layouts remain.
- Ensure the layout is a standard grid.

### [Person Details Feature](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/person_details)

#### [MODIFY] [person_details_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/person_details/presentation/screens/person_details_screen.dart)
- Replace the `CustomScrollView` and `SliverAppBar.large` with a standard `Scaffold` and `AppBar`.
- Move the current `SliverToBoxAdapter` and `SliverGrid` contents into a `SingleChildScrollView` with a `Column`.
- Remove any remaining "complex" UI elements to restore the simpler design.

#### [MODIFY] [person_details_repository.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/person_details/data/repositories/person_details_repository.dart)
- Verify that `getPersonDetails` only performs standard API calls and does not invoke AI for missing biographies. (Currently it is already clean).

### [AI Assistant Feature](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/ai_assistant)

#### [MODIFY] [chat_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/ai_assistant/presentation/screens/chat_screen.dart)
- Simplify the `_ChatBubble` design to use standard `BorderRadius` and basic styling.
- Ensure "Quick Prompts" are not present (currently they are not found).

#### [MODIFY] [chat_provider.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/ai_assistant/presentation/providers/chat_provider.dart)
- Maintain the current OpenAI integration as it seems to be the core "Assistant" logic, but check for any "Fail-Safe" logic that needs to be preserved or restored.

## Verification Plan

### Manual Verification
- Run the app and verify the Home screen shows a standard grid without category chips.
- Navigate to the Details screen and verify it uses a standard `AppBar` and scrolls normally.
- Open the Chat screen and verify the bubble design is simple and no quick prompts are visible.
- Check logs to ensure no AI calls are made during person detail loading.
