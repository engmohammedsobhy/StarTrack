import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itiproject/core/services/persona_label_service.dart';
import 'package:itiproject/core/widgets/persona_label_chip.dart';
import 'package:itiproject/features/home/data/models/entity_model.dart';

void main() {
  group('PersonaLabelService Unit Tests', () {
    test('Returns exact curated labels for Lionel Messi', () {
      final labels = PersonaLabelService.getLabelsForPersona('Lionel Messi');
      expect(labels, contains('Argentina'));
      expect(labels, contains('Football Player'));
      expect(labels, contains('Football Legend'));
      expect(labels.length, greaterThanOrEqualTo(4));
    });

    test('Returns exact curated labels for Sonic the Hedgehog', () {
      final labels = PersonaLabelService.getLabelsForPersona('Sonic the Hedgehog');
      expect(labels, contains('Blue'));
      expect(labels, contains('Hedgehog'));
      expect(labels, contains('Video Game Character'));
      expect(labels, contains('Super Speed'));
    });

    test('Returns exact curated labels for Sonic abbreviation', () {
      final labels = PersonaLabelService.getLabelsForPersona('Sonic');
      expect(labels, contains('Blue'));
      expect(labels, contains('Hedgehog'));
      expect(labels, contains('Video Game Character'));
    });

    test('Dynamic fallback generates relevant labels for uncurated persona', () {
      final labels = PersonaLabelService.getLabelsForPersona(
        'Kylian Mbappe',
        'French professional footballer who plays as a forward',
      );
      expect(labels, contains('French'));
      expect(labels, contains('Football Player'));
    });

    test('Pastel colors are distinct and adjacent chips have different colors', () {
      final color0 = PersonaLabelService.getLabelBackgroundColor(0);
      final color1 = PersonaLabelService.getLabelBackgroundColor(1);
      final color2 = PersonaLabelService.getLabelBackgroundColor(2);

      expect(color0, isNot(equals(color1)));
      expect(color1, isNot(equals(color2)));
      expect(color0, isNot(equals(color2)));

      // Reference image colors verification
      expect(color0, equals(const Color(0xFFBAE6FD))); // Soft sky blue (Flowers)
      expect(color1, equals(const Color(0xFFD9F2B4))); // Soft lime (Tangerine)
      expect(color2, equals(const Color(0xFFFFDFBA))); // Soft peach / almond (Almond)
    });

    test('Reverse lookup finds personas matching a label', () {
      final argentinaPersonas = PersonaLabelService.getPersonaNamesForLabel('Argentina');
      expect(argentinaPersonas, contains('Lionel Messi'));

      final hedgehogPersonas = PersonaLabelService.getPersonaNamesForLabel('Hedgehog');
      expect(hedgehogPersonas.any((name) => name.toLowerCase().contains('sonic')), isTrue);

      final footballPersonas = PersonaLabelService.getPersonaNamesForLabel('Football Player');
      expect(footballPersonas, contains('Lionel Messi'));
      expect(footballPersonas, contains('Cristiano Ronaldo'));
    });

    test('Dynamic fallback NEVER includes generic filler words', () {
      final labels = PersonaLabelService.getLabelsForPersona(
        'Some Historical Figure',
        'French military officer (1769–1821)',
      );
      expect(labels, contains('French'));
      expect(labels, isNot(contains('Notable Figure')));
      expect(labels, isNot(contains('Icon')));
      expect(labels, isNot(contains('Cultural Legend')));
    });

    test('cleanWikidataAttributeName correctly cleans attributes', () {
      expect(PersonaLabelService.cleanWikidataAttributeName('association football player'), equals('Football Player'));
      expect(PersonaLabelService.cleanWikidataAttributeName('united states of america'), equals('United States'));
      expect(PersonaLabelService.cleanWikidataAttributeName('human'), equals(''));
      expect(PersonaLabelService.cleanWikidataAttributeName('notable figure'), equals(''));
    });

    test('popularSearchLabels has diverse attributes for searching', () {
      expect(PersonaLabelService.popularSearchLabels, contains('Football Player'));
      expect(PersonaLabelService.popularSearchLabels, contains('Argentina'));
      expect(PersonaLabelService.popularSearchLabels, contains('Theoretical Physicist'));
      // Comprehensive super-categories
      expect(PersonaLabelService.popularSearchLabels, contains('Athlete'));
      expect(PersonaLabelService.popularSearchLabels, contains('Scientist'));
      expect(PersonaLabelService.popularSearchLabels, contains('Actor'));
      expect(PersonaLabelService.popularSearchLabels, contains('Musician'));
      expect(PersonaLabelService.popularSearchLabels, contains('Political Leader'));
      expect(PersonaLabelService.popularSearchLabels, contains('Video Game Character'));
      expect(PersonaLabelService.popularSearchLabels, contains('Author'));
      expect(PersonaLabelService.popularSearchLabels, contains('Visual Artist'));
      expect(PersonaLabelService.popularSearchLabels, contains('Nobel Laureate'));
      expect(PersonaLabelService.popularSearchLabels, contains('World Cup Champion'));
    });

    test('All-encompassing super-categories are assigned to iconic personas', () {
      final messiLabels = PersonaLabelService.getLabelsForPersona('Lionel Messi');
      expect(messiLabels, contains('Athlete'));

      final einsteinLabels = PersonaLabelService.getLabelsForPersona('Albert Einstein');
      expect(einsteinLabels, contains('Scientist'));
      expect(einsteinLabels, contains('Physics'));

      final sonicLabels = PersonaLabelService.getLabelsForPersona('Sonic the Hedgehog');
      expect(sonicLabels, contains('Video Game Character'));

      final baleLabels = PersonaLabelService.getLabelsForPersona('Christian Bale');
      expect(baleLabels, contains('Actor'));
      expect(baleLabels, contains('Cinema & Film'));

      final lincolnLabels = PersonaLabelService.getLabelsForPersona('Abraham Lincoln');
      expect(lincolnLabels, contains('Political Leader'));

      final beethovenLabels = PersonaLabelService.getLabelsForPersona('Ludwig van Beethoven');
      expect(beethovenLabels, contains('Musician'));

      final shakespeareLabels = PersonaLabelService.getLabelsForPersona('William Shakespeare');
      expect(shakespeareLabels, contains('Author'));

      final picassoLabels = PersonaLabelService.getLabelsForPersona('Pablo Picasso');
      expect(picassoLabels, contains('Visual Artist'));
    });

    test('Reverse lookup groups multiple personas under comprehensive super-categories', () {
      final athletes = PersonaLabelService.getPersonaNamesForLabel('Athlete');
      expect(athletes, contains('Lionel Messi'));
      expect(athletes, contains('Cristiano Ronaldo'));
      expect(athletes, contains('Diego Maradona'));
      expect(athletes, contains('Pele'));

      final scientists = PersonaLabelService.getPersonaNamesForLabel('Scientist');
      expect(scientists, contains('Albert Einstein'));
      expect(scientists, contains('Marie Curie'));
      expect(scientists, contains('Isaac Newton'));

      final actors = PersonaLabelService.getPersonaNamesForLabel('Actor');
      expect(actors, contains('Christian Bale'));
      expect(actors, contains('Robert De Niro'));

      final leaders = PersonaLabelService.getPersonaNamesForLabel('Political Leader');
      expect(leaders, contains('Abraham Lincoln'));
      expect(leaders, contains('Winston Churchill'));
      expect(leaders, contains('Nelson Mandela'));

      final directors = PersonaLabelService.getPersonaNamesForLabel('Film Director');
      expect(directors, contains('Christopher Nolan'));
      expect(directors, contains('Quentin Tarantino'));
      expect(directors, contains('Steven Spielberg'));

      final philosophers = PersonaLabelService.getPersonaNamesForLabel('Philosopher');
      expect(philosophers, contains('Aristotle'));
      expect(philosophers, contains('Plato'));
      expect(philosophers, contains('Socrates'));
    });

    test('Christopher Nolan has accurate labels and no chivalric orders', () {
      final nolanLabels = PersonaLabelService.getLabelsForPersona('Christopher Nolan');
      expect(nolanLabels, contains('Film Director'));
      expect(nolanLabels, contains('Filmmaker'));
      expect(nolanLabels, contains('Academy Award Winner'));
      expect(nolanLabels, contains('Cinema & Film'));
      expect(nolanLabels, isNot(contains('Commander of the Order of the British Empire')));
      expect(nolanLabels, isNot(contains('Awards')));
    });

    test('cleanAndFilterLabels strips chivalric orders, decorations, and raw awards', () {
      final filtered = PersonaLabelService.cleanAndFilterLabels([
        'Commander of the Order of the British Empire',
        'Awards',
        'Empire Awards',
        'Knight Bachelor',
        'Film Director',
        'Cinema & Film',
      ]);
      expect(filtered, equals(['Film Director', 'Cinema & Film']));
    });
  });

  group('KnowledgeEntity effectiveLabels Tests', () {
    test('Entity uses curated labels if none explicitly passed', () {
      final entity = KnowledgeEntity(
        id: 'messi',
        title: 'Lionel Messi',
        description: 'Footballer',
      );

      expect(entity.effectiveLabels, contains('Argentina'));
      expect(entity.effectiveLabels, contains('Football Player'));
    });

    test('Entity preserves explicitly passed labels', () {
      final entity = KnowledgeEntity(
        id: 'custom',
        title: 'Custom Persona',
        labels: ['Custom1', 'Custom2'],
      );

      expect(entity.effectiveLabels, equals(['Custom1', 'Custom2']));
    });
  });

  group('PersonaLabelChip and PersonaLabelsRow Widget Tests', () {
    testWidgets('PersonaLabelChip renders text and responds to tap', (tester) async {
      String? tapped;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonaLabelChip(
              label: 'Argentina',
              index: 0,
              onTap: () {
                tapped = 'Argentina';
              },
            ),
          ),
        ),
      );

      expect(find.text('Argentina'), findsOneWidget);

      await tester.tap(find.text('Argentina'));
      await tester.pumpAndSettle();

      expect(tapped, equals('Argentina'));
    });

    testWidgets('PersonaLabelsRow renders multiple pastel chips with onLabelTap callback', (tester) async {
      final labels = ['Argentina', 'Football Player', 'Football Legend'];
      String? clickedLabel;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonaLabelsRow(
              labels: labels,
              scrollable: false,
              onLabelTap: (label) {
                clickedLabel = label;
              },
            ),
          ),
        ),
      );

      expect(find.text('Argentina'), findsOneWidget);
      expect(find.text('Football Player'), findsOneWidget);
      expect(find.text('Football Legend'), findsOneWidget);

      await tester.tap(find.text('Football Player'));
      await tester.pumpAndSettle();

      expect(clickedLabel, equals('Football Player'));
    });

    testWidgets('PersonaLabelsRow horizontal scrollable mode renders successfully', (tester) async {
      final labels = ['Blue', 'Hedgehog', 'Video Game Character', 'Super Speed', 'SEGA Icon'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonaLabelsRow(
              labels: labels,
              scrollable: true,
            ),
          ),
        ),
      );

      expect(find.text('Blue'), findsOneWidget);
      expect(find.text('Hedgehog'), findsOneWidget);
    });
  });
}
