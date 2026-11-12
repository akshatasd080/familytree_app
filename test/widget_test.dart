import 'package:flutter_test/flutter_test.dart';

import 'package:familytree_app/app/app.dart';

void main() {
  testWidgets('Public home loads', (WidgetTester tester) async {
    await tester.pumpWidget(const FamilyTreeApp());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Family'), findsWidgets);
  });
}
