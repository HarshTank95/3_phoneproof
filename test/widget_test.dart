import 'package:flutter_test/flutter_test.dart';

import 'package:phoneproof/main.dart';

void main() {
  testWidgets('PhoneProof launches on the mode screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PhoneProofApp());
    await tester.pump();

    expect(find.text('PhoneProof'), findsWidgets);
  });
}
