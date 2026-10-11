import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sertio/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Sertio opens the studio workspace', (tester) async {
    await tester.pumpWidget(const NovaStudioApp());
    await tester.pump();
    expect(find.textContaining('Welcome to Sertio'), findsOneWidget);
  });
}
