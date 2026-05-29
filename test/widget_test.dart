import 'package:flutter_test/flutter_test.dart';

import 'package:mango_health/main.dart';

void main() {
  testWidgets('App shows Mango Health home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MangoHealthApp());
    await tester.pump();

    expect(find.text('Mango Health'), findsOneWidget);
    expect(find.textContaining('Health access needed'), findsOneWidget);
  });
}
