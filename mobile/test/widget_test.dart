import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:unbound_mobile/main.dart';
import 'package:unbound_mobile/services/auth_service.dart';

void main() {
  testWidgets('Carga inicial de la aplicación UNBOUND', (WidgetTester tester) async {
    final authService = AuthService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: authService),
        ],
        child: const UnboundApp(),
      ),
    );

    expect(find.text('Expedientes Digitales'), findsOneWidget);
  });
}
