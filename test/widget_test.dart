import 'package:flutter_test/flutter_test.dart';
import 'package:isometric/main.dart';

void main() {
  testWidgets('IsometricApp smoke test - mounts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const IsometricApp());
    // App builds and loads cleanly
    expect(find.byType(IsometricApp), findsOneWidget);
  });
}
