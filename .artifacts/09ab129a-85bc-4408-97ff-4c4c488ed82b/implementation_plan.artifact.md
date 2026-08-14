# Implementation Plan - Home Screen UI Cleanup

Remove the "Top Picks" carousel and the "Family-Friendly" badge from the Home Screen to allow the celebrity grid to occupy the full screen height.

## Proposed Changes

### [Home Screen](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/home/presentation/screens/home_screen.dart)

#### [MODIFY] [home_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/home/presentation/screens/home_screen.dart)
- Remove `carousel_slider` import.
- Remove the `Family Friendly` Chip from the `AppBar` actions.
- Remove the `SliverToBoxAdapter` containing the "Top Picks" carousel and the "Discover Stars" header.
- Remove the `_TopPickCard` private widget class.

### [Project Dependencies](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/pubspec.yaml)

#### [MODIFY] [pubspec.yaml](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/pubspec.yaml)
- Remove `carousel_slider` dependency.

## Verification Plan

### Manual Verification
- Verify that the "Family Friendly" badge is no longer visible in the App Bar.
- Verify that the "Top Picks" carousel is gone.
- Verify that the celebrity grid starts immediately below the App Bar.
- Ensure the app still builds and runs without errors.
