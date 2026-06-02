import 'package:flutter_test/flutter_test.dart';
import 'package:sales_ai_seller/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SellerApp());
    await tester.pumpAndSettle();
    expect(find.text('INGRESAR'), findsOneWidget);
  });
}
