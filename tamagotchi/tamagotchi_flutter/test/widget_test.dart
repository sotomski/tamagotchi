import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tamagotchi_flutter/app/app_widget.dart';

void main() {
  testWidgets('App boots into the home placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AppWidget()));
    await tester.pumpAndSettle();

    expect(find.text('No creature yet'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
