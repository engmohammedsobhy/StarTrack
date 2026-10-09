import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itiproject/core/services/persona_label_service.dart';
import 'package:itiproject/features/home/presentation/screens/home_screen.dart';
import 'package:itiproject/app_router.dart';

void main() {
  group('Home Search & Dynamic Labels Integration Tests', () {
    test('getMatchingLabels returns popular comprehensive labels when query is empty', () {
      final labels = PersonaLabelService.getMatchingLabels('');
      expect(labels, contains('Athlete'));
      expect(labels, contains('Scientist'));
      expect(labels, contains('Actor'));
      expect(labels, contains('Political Leader'));
      expect(labels, contains('Nobel Laureate'));
      expect(labels, contains('Football Player'));
    });

    test('getMatchingLabels filters dynamically while typing', () {
      final footLabels = PersonaLabelService.getMatchingLabels('foot');
      expect(footLabels, contains('Football Player'));
      expect(footLabels.first.toLowerCase(), startsWith('foot'));

      final sciLabels = PersonaLabelService.getMatchingLabels('sci');
      expect(sciLabels, contains('Scientist'));

      final polLabels = PersonaLabelService.getMatchingLabels('pol');
      expect(polLabels, contains('Political Leader'));
      expect(polLabels, contains('Poland'));

      final nobelLabels = PersonaLabelService.getMatchingLabels('nobel');
      expect(nobelLabels, contains('Nobel Laureate'));
    });

    testWidgets('MainScreen has 3 destinations and no separate search page tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom navigation destinations
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.destinations.length, equals(3));

      // Destinations are Home, Ask AI, Saved
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Ask AI'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);

      // Search tab is NOT in bottom nav
      expect(find.text('Search'), findsNothing);
    });

    testWidgets('HomeScreen search button toggles search box with dynamic labels under', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Initially search box is not open
      expect(find.byType(TextField), findsNothing);
      expect(find.byTooltip('Search Personas'), findsOneWidget);

      // Tap search button in app bar
      await tester.tap(find.byTooltip('Search Personas'));
      await tester.pumpAndSettle();

      // Search box is now visible
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search personas, professions...'), findsOneWidget);

      // Labels are rendered directly under the search box
      expect(find.text('Athlete'), findsOneWidget);
      expect(find.text('Scientist'), findsOneWidget);

      // Tap close search button — now it's the X inside the search box
      await tester.tap(find.byTooltip('Close Search'));
      await tester.pumpAndSettle();

      // Search box closes
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Typing in search box dynamically updates labels underneath', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Open search
      await tester.tap(find.byTooltip('Search Personas'));
      await tester.pumpAndSettle();

      // Enter 'foot' into search box
      await tester.enterText(find.byType(TextField), 'foot');
      await tester.pumpAndSettle();

      // Labels under search box now show matching labels
      expect(find.text('Football Player'), findsOneWidget);

      // Tap the label chip — should select it as a filter, NOT fill the text field
      await tester.tap(find.text('Football Player'));
      await tester.pumpAndSettle();

      // After tapping a label chip, the text field is cleared (label filter takes over)
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, equals(''));

      // The label 'Football Player' is still shown as a selected chip in the labels row
      expect(find.text('Football Player'), findsOneWidget);
    });
  });
}
