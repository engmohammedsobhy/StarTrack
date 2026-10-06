import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'features/home/data/models/entity_model.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/person_details/presentation/screens/person_details_screen.dart';
import 'features/favorites/presentation/screens/favorites_screen.dart';
import 'features/ai_assistant/presentation/screens/chat_screen.dart';
import 'features/search/presentation/screens/search_screen.dart';
import 'main_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      pageBuilder: (context, state, child) => NoTransitionPage(
        child: MainScreen(child: child),
      ),
      routes: [
        GoRoute(
          path: '/', 
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/search',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SearchScreen(),
          ),
        ),
        GoRoute(
          path: '/chat',
          pageBuilder: (context, state) {
            final entity = state.extra as KnowledgeEntity?;
            return NoTransitionPage(
              child: ChatScreen(entity: entity),
            );
          },
        ),
        GoRoute(
          path: '/favorites',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: FavoritesScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/person/:id',
      builder: (context, state) {
        final entity = state.extra as KnowledgeEntity;
        return PersonDetailsScreen(entity: entity);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/person_chat',
      builder: (context, state) {
        final entity = state.extra as KnowledgeEntity?;
        return ChatScreen(entity: entity);
      },
    ),
  ],
);
