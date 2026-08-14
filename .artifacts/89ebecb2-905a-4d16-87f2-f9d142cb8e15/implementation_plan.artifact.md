# Implementation Plan - Enhance Favorites Screen UI/UX

This plan outlines the enhancements for the Favorites screen, including a new empty state, refined card designs with "Known For" badges, and better management actions.

## User Review Required

> [!NOTE]
> The project uses Flutter and Riverpod. While my core expertise includes Jetpack Compose, I will implement these enhancements in Dart/Flutter to maintain architectural consistency and ensure immediate functionality within the existing project.

## Proposed Changes

### Domain & Data Layer

#### [MODIFY] [person_model.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/home/data/models/person_model.dart)
- Add `knownForDepartment` field to the `Person` class.
- Update `fromJson` and `toJson` to handle the new field.

#### [MODIFY] [favorites_provider.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/favorites/presentation/providers/favorites_provider.dart)
- Add a `clearAll` method to `FavoritesNotifier` to remove all favorite items.

### Presentation Layer

#### [MODIFY] [favorites_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/favorites/presentation/screens/favorites_screen.dart)
- **Empty State**:
    - Overhaul `_buildEmptyState` with a large `favorite_border` icon.
    - Add a soft Cyan glow effect using `BoxShadow`.
    - Rename "Explore Popular People" to "Explore Stars" and ensure it navigates to `/`.
- **Card Design**:
    - Update `_buildFavoriteCard` to include a badge for `knownForDepartment`.
    - Style the "Quick Unfavorite" button (filled heart or X) on the top right.
    - Ensure responsiveness for desktop by refining the `GridView` constraints.
- **AppBar Actions**:
    - Add a "Clear All" icon button in the `AppBar`.
    - Implement a confirmation `AlertDialog` before clearing all favorites.

## Visual Polish
- Use the **Poppins** font (already configured in `main.dart`).
- Apply the **Cyan** accent consistently across the new components.
- Ensure smooth UI transitions when items are removed.

## Verification Plan

### Automated Tests
- Since this is a UI enhancement, I will manually verify the layout and interactions if possible (e.g., checking code consistency and responsiveness logic).

### Manual Verification
- Verify the new Empty State appears when no favorites are present.
- Verify the "Explore Stars" button navigates back to the Home screen.
- Verify the "Known For" badge is visible on celebrity cards in the Favorites screen.
- Verify the "Quick Unfavorite" button removes the item and updates the UI.
- Verify the "Clear All" action works as expected with the confirmation dialog.
