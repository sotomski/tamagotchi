import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_flutter/creature/critter_image.dart';

void main() {
  group('CritterImage', () {
    testWidgets('renders nothing for a null imageUrl', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: CritterImage(imageUrl: null))),
      );
      await tester.pumpAndSettle();

      // No image mounted, and the widget collapses to a zero-size box — a
      // pre-feature creature shows the rest of the view with no layout break.
      expect(find.byType(Image), findsNothing);
      expect(find.byKey(const Key('critterImage')), findsNothing);
      expect(tester.getSize(find.byType(CritterImage)), Size.zero);
    });

    testWidgets('mounts a network Image and reserves the default box', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CritterImage(imageUrl: 'https://example.test/critter.jpg'),
          ),
        ),
      );
      // A single pump — the bytes are still in flight, but the Image widget is
      // mounted and the box is already reserved so the column never reflows.
      await tester.pump();

      expect(find.byKey(const Key('critterImage')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.getSize(find.byType(CritterImage)), const Size(128, 128));
    });

    testWidgets('honours a custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CritterImage(
              imageUrl: 'https://example.test/critter.jpg',
              size: 64,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.getSize(find.byType(CritterImage)), const Size(64, 64));
    });
  });
}
