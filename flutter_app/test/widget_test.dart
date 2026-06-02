import 'package:flutter_test/flutter_test.dart';
import 'package:sales_ai_store/main.dart';

void main() {
  testWidgets('App carga sin errores', (WidgetTester tester) async {
    await tester.pumpWidget(const SalesStoreApp());
    expect(find.text('Tienda'), findsOneWidget);
  });
}
