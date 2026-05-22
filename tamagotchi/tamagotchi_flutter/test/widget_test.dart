import 'package:flutter_test/flutter_test.dart';

import 'package:tamagotchi_flutter/main.dart';

void main() {
  testWidgets('MyApp builds and renders the home page', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Serverpod Example'), findsOneWidget);
  });
}
