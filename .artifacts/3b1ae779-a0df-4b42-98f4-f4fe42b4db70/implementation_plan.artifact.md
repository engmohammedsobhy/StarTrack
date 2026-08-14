# Visual Identity Enhancement Plan

Enhance the StarTrack app with modern typography and a vibrant Electric Purple accent color, strictly adhering to Dark Mode.

## Proposed Changes

### Dependencies
#### [MODIFY] [pubspec.yaml](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/pubspec.yaml)
- Add `google_fonts: ^6.2.1` to dependencies.

### Theme & Typography
#### [MODIFY] [main.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/main.dart)
- Define `accentColor = Color(0xFF6200EE)`.
- Use `GoogleFonts.poppinsTextTheme()` for global typography.
- Update `ThemeData` and `darkTheme` with `ColorScheme.fromSeed(seedColor: accentColor)`.
- Set `ThemeMode.dark` explicitly.
- Customize `AppBarTheme` with surface color and elevation.

### UI Polish & Consistency
#### [MODIFY] [home_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/home/presentation/screens/home_screen.dart)
- Ensure FAB and icons use theme-derived colors.
- Update Favorite icon active color to use `colorScheme.primary` (the vibrant accent).

#### [MODIFY] [favorites_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/favorites/presentation/screens/favorites_screen.dart)
- Update Favorite icon active color to use `colorScheme.primary`.

#### [MODIFY] [chat_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/ai_assistant/presentation/screens/chat_screen.dart)
- Verify welcome icon and user bubbles use `colorScheme.primary`.

#### [MODIFY] [person_details_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/person_details/presentation/screens/person_details_screen.dart)
- Update Favorite icon active color to use `colorScheme.primary`.
- Ensure chips and action buttons reflect the new theme.

## Verification Plan
### Automated Tests
- Run `flutter pub get` to install new dependency.
- Build the app to ensure no compilation errors.

### Manual Verification
- Visual inspection of all screens in the IDE (or instructions for the user) to verify 'Poppins' font and 'Electric Purple' accent.
- Check Dark Mode consistency.
