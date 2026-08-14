# Implementation Plan - Update Accent Color to Red

The goal is to change the app's accent color from Cyan to Red globally, ensuring consistent styling across all screens and components while maintaining Dark Mode.

## Proposed Changes

### [Theming]
#### [MODIFY] [main.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/main.dart)
- Update `darkTheme` `ColorScheme.fromSeed` to use `Colors.red` and `Colors.redAccent`.
- Update `surfaceTintColor` in `AppBarTheme` to use `Colors.red`.

### [AI Assistant]
#### [MODIFY] [chat_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/ai_assistant/presentation/screens/chat_screen.dart)
- Replace hardcoded `Colors.cyan` with `Theme.of(context).colorScheme.primary` or `Colors.red`.

### [Favorites]
#### [MODIFY] [favorites_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/favorites/presentation/screens/favorites_screen.dart)
- Replace hardcoded `Colors.cyan` with `Theme.of(context).colorScheme.primary` or `Colors.red`.

### [Person Details]
#### [MODIFY] [person_details_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/person_details/presentation/screens/person_details_screen.dart)
- Update `SnackBar` background color from `Colors.cyan.shade800` to `Colors.red.shade800` or theme primary.

## Verification Plan
### Manual Verification
- Check all screens (Home, Details, Favorites, Chat) to ensure the accent color is now Red.
- Verify that FABs, icons, chips, and progress indicators reflect the new color.
- Ensure contrast is good against the dark background.
