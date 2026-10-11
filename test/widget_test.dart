import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nova_studio_ai/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Nova Studio AI opens the studio workspace', (tester) async {
    await tester.pumpWidget(const NovaStudioApp());
    await tester.pump();
    expect(find.textContaining('Welcome to Nova Studio AI'), findsOneWidget);
  });
}
