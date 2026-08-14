# Implementation Plan - Add Windows Support and Responsive UI

This plan outlines the steps to add Windows desktop support to the StarTrack Flutter project and ensure the UI is responsive and functional on larger screens.

## Proposed Changes

### Configuration

#### [MODIFY] [pubspec.yaml](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/pubspec.yaml)
- Verify dependencies for Windows support (already done, `insta_image_viewer` and other core packages support Windows).

### UI & UX (Responsive Design)

#### [MODIFY] [home_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/home/presentation/screens/home_screen.dart)
- Update `GridView` `crossAxisCount` to be dynamic based on screen width.
- Use `LayoutBuilder` or `MediaQuery` to determine the column count.

#### [MODIFY] [favorites_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/favorites/presentation/screens/favorites_screen.dart)
- Convert `ListView` to `GridView` for desktop/large screens for consistency with the Home screen.
- Implement dynamic `crossAxisCount`.

#### [MODIFY] [chat_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/ai_assistant/presentation/screens/chat_screen.dart)
- Constrain the width of the chat bubbles and input area on large screens to improve readability.
- Center the content with a `MaxWith` container or `Padding`.

#### [MODIFY] [person_details_screen.dart](file:///C:/Users/mlead/AndroidStudioProjects/ITIproject/lib/features/person_details/presentation/screens/person_details_screen.dart)
- Update `_downloadImage` to support Windows.
- Use `getDownloadsDirectory()` for Windows.
- Skip permission requests on Windows as they are typically not required for the Downloads folder in Win32 apps.

## Verification Plan

### Automated Tests
- Run `flutter build windows` (if the environment allows) or `flutter doctor` to check for Windows setup.

### Manual Verification
- Verify responsiveness by resizing the window (simulated via `MediaQuery` or desktop run).
- Check that all features (Celebrity List, AI Chat, Favorites, Details) work as expected on a desktop-like layout.
