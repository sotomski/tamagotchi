import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tamagotchi_flutter/app/retro_loader.dart';

void main() {
  testWidgets('renders one square block per blockCount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: RetroLoader(blockCount: 5))),
      ),
    );
    // Single pump — the marching animation never settles (like a spinner).
    await tester.pump();

    expect(find.byType(RetroLoader), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RetroLoader),
        matching: find.byType(Container),
      ),
      findsNWidgets(5),
    );
  });
}
