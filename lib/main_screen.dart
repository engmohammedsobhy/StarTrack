import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/search/presentation/providers/search_provider.dart';

class MainScreen extends ConsumerWidget {
  final Widget child;

  const MainScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (int index) => _onItemTapped(index, context, ref),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_filled),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Ask AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_outline),
            selectedIcon: Icon(Icons.bookmark),
            label: 'Saved',
          ),
        ],
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/chat')) {
      return 1;
    }
    if (location.startsWith('/favorites')) {
      return 2;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, WidgetRef ref) {
    switch (index) {
      case 0:
        final String location = GoRouterState.of(context).uri.path;
        if (location == '/') {
          final isOpen = ref.read(homeSearchOpenProvider);
          ref.read(homeSearchOpenProvider.notifier).state = !isOpen;
        } else {
          context.go('/');
        }
        break;
      case 1:
        context.go('/chat');
        break;
      case 2:
        context.go('/favorites');
        break;
    }
  }
}
