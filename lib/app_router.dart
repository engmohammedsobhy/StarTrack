import 'package:go_router/go_router.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'features/person_details/presentation/screens/person_details_screen.dart';
import 'features/favorites/presentation/screens/favorites_screen.dart';
import 'features/ai_assistant/presentation/screens/chat_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(
      path: '/person/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PersonDetailsScreen(personId: id);
      },
    ),
  ],
);
