# Project Plan

A Flutter application that fetches and displays popular persons from TMDB. 
Features include:
1. Home Screen: List/Grid of popular persons using TMDB API.
2. Details Screen: Detailed info and an image gallery for a specific person.
3. Image Viewer: Full-screen image view with zoom and download capabilities.
4. AI Chat Bot: Simple generative AI chat (Gemini/OpenAI) with loading and error states.
5. Favorites: Ability to like/unlike persons, with a dedicated view for favorites.

APIs:
- Popular Persons: https://api.themoviedb.org/3/person/popular?api_key=2dfe23358236069710a379edd4c65a6b
- Person Details: https://api.themoviedb.org/3/person/$id?api_key=2dfe23358236069710a379edd4c65a6b
- Person Images: https://api.themoviedb.org/3/person/$id/images?api_key=2dfe23358236069710a379edd4c65a6b

## Project Brief

# Project Brief: TMDB Popular Persons (Flutter Edition)

This project is a mobile application built with Flutter that allows users to discover, explore, and interact with popular figures from the movie industry using data from The Movie Database (TMDB).

## Features
1.  **Popular Persons Discovery**: A responsive grid/list interface showcasing trending celebrities from TMDB, featuring high-quality posters and names.
2.  **Rich Celebrity Profiles**: A detailed view for each person including their biography, career details, and an integrated gallery of images.
3.  **Immersive Image Viewer**: A full-screen experience for celebrity photos supporting pinch-to-zoom, panning, and direct image downloads using `insta_image_viewer`.
4.  **AI Celebrity Assistant**: A built-in chat interface powered by Gemini AI, allowing users to ask questions about celebrities with real-time loading and error feedback.
5.  **Favorites Collection**: A dedicated space for users to "like" and save their favorite celebrities for offline-ready access.

## High-Level Technical Stack
-   **Language**: Dart
-   **Framework**: Flutter
-   **State Management**: Riverpod (for robust, reactive state handling)
-   **Networking**: Dio (for high-performance TMDB API integration)
-   **Generative AI**: `google_generative_ai` (Official SDK for Gemini integration)
-   **Navigation**: `go_router` (for declarative, URL-based routing across screens)
-   **UI Enhancement**: `insta_image_viewer` (for advanced image viewing) and `cached_network_image` (for efficient media loading)

## Implementation Steps
**Total Duration:** 25m 36s

### Task_1_ProjectSetup_HomeScreen: Initialize Flutter project, configure dependencies (Riverpod, Dio, GoRouter, cached_network_image), integrate TMDB API with key 2dfe23358236069710a379edd4c65a6b, and implement the Home Screen grid/list of popular persons.
- **Status:** COMPLETED
- **Updates:** Initialized Flutter project, set up dependencies (Riverpod, Dio, GoRouter, cached_network_image), implemented TMDB networking layer, and built the Home Screen with a grid of celebrities. Placeholder favorite icons added.
- **Acceptance Criteria:**
  - pubspec.yaml configured with core dependencies
  - TMDB API fetching for popular persons is functional
  - Home Screen displays a responsive grid of celebrities
  - API_KEY integration confirmed
- **Duration:** 2m 53s

### Task_2_DetailsScreen_ImageViewer: Create the Person Details screen showing biography, career details, and an image gallery. Implement the immersive image viewer using insta_image_viewer for pinch-to-zoom and download support.
- **Status:** COMPLETED
- **Updates:** Implemented the Person Details screen with full biography and career details. Integrated an image gallery using the `insta_image_viewer` package for full-screen viewing, zooming, and panning. Added a download feature for images using `dio` and `path_provider`. Configured permissions and routing for the details view.
- **Acceptance Criteria:**
  - Details screen displays biography and career info
  - Gallery shows high-quality images of the person
  - Full-screen viewer supports zoom, panning, and download functionality
- **Duration:** 3m 54s

### Task_3_AIChat_Favorites: Integrate google_generative_ai (Gemini) for the AI Celebrity Assistant. Implement favorites logic using Riverpod for state management and create a dedicated Favorites view.
- **Status:** COMPLETED
- **Updates:** Integrated Gemini API key, implemented the AI Assistant chat interface, created the Favorites feature with persistence using Riverpod and SharedPreferences, and performed a final UI polish across all screens including Hero animations and Material 3 elements.
- **Acceptance Criteria:**
  - Gemini AI returns responses in the chat interface
  - Loading and error states handled in chat
  - Users can favorite/unfavorite celebrities
  - Favorites view correctly lists saved persons
- **Duration:** 18m 49s

### Task_4_FinalRun_Verify: Perform a final run of the application to verify stability, feature completeness, and alignment with the project brief. Ensure all existing tests pass and the UI is consistent.
- **Status:** IN_PROGRESS
- **Acceptance Criteria:**
  - App builds and runs without crashes
  - Navigation works across all screens
  - All features (TMDB, Gemini, Favorites) verified
  - Build passes and app is stable
- **StartTime:** 2026-08-06 11:19:25 EEST

