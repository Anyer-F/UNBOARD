import 'package:flutter/widgets.dart';
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

    expect(find.text('UNBOUND DMS'), findsOneWidget);

    // Desmonta la app y deja vencer el temporizador del splash
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
