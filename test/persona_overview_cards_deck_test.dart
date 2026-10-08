import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';
import 'package:itiproject/features/person_details/data/models/rag_response_model.dart';
import 'package:itiproject/features/person_details/presentation/widgets/persona_overview_cards_deck.dart';

void main() {
  final dummyEntity = KnowledgeEntity(
    id: 'Q45785',
    title: 'Christian Bale',
    description: 'English actor',
  );

  final dummyCards = [
    const OverviewCardModel(
      title: 'Who is Christian Bale?',
      content: 'Academy Award-winning actor celebrated for extreme physical transformations.',
    ),
    const OverviewCardModel(
      title: 'Origins & Early Life',
      content: 'Born in Wales, Bale made his screen breakthrough in Empire of the Sun.',
    ),
    const OverviewCardModel(
      title: 'The Dark Knight & Breakthroughs',
      content: 'Redefined comic book cinema in Christopher Nolan’s Dark Knight Trilogy.',
    ),
    const OverviewCardModel(
      title: 'Uncompromising Method Acting',
      content: 'Undergoes radical body transformations to inhabit his roles completely.',
    ),
    const OverviewCardModel(
      title: 'Academy Award & Golden Globes',
      content: 'Won the Oscar for Best Supporting Actor for The Fighter in 2011.',
    ),
    const OverviewCardModel(
      title: 'Cultural Impact & Legacy',
      content: 'Widely cited by contemporary actors as the gold standard of dramatic dedication.',
    ),
    const OverviewCardModel(
      title: 'Fascinating Curiosities',
      content: 'Turned down a 4th Batman film out of respect for Christopher Nolan’s vision.',
    ),
  ];

  testWidgets('PersonaOverviewCardsDeck renders header, count badge, and simple card content without labels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonaOverviewCardsDeck(
            cards: dummyCards,
            entity: dummyEntity,
          ),
        ),
      ),
    );

    // Verify section title and count badge
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('1/7'), findsOneWidget);

    // Verify first card contents (Header and content under)
    expect(find.text('Who is Christian Bale?'), findsOneWidget);
    expect(find.text('Academy Award-winning actor celebrated for extreme physical transformations.'), findsOneWidget);

    // Verify extra labels/badges are NOT present
    expect(find.text('Ask AI about this'), findsNothing);
    expect(find.text('Next'), findsNothing);
    expect(find.text('IDENTITY'), findsNothing);
  });

  testWidgets('PersonaOverviewCardsDeck navigates cards via next arrow button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonaOverviewCardsDeck(
            cards: dummyCards,
            entity: dummyEntity,
          ),
        ),
      ),
    );

    expect(find.text('1/7'), findsOneWidget);

    // Tap the chevron right button to advance to next card
    final nextButton = find.byIcon(Icons.chevron_right_rounded);
    expect(nextButton, findsOneWidget);
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Verify card advanced to 2/7
    expect(find.text('2/7'), findsOneWidget);
    expect(find.text('Origins & Early Life'), findsOneWidget);
    expect(find.text('Born in Wales, Bale made his screen breakthrough in Empire of the Sun.'), findsOneWidget);
  });
}
