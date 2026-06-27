import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_factura/main.dart';
import 'package:app_factura/theme_provider.dart';

void main() {
  testWidgets('renderiza navegacion principal de la app', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Inicio'), findsAtLeastNWidgets(1));
    expect(find.text('Correo'), findsAtLeastNWidgets(1));
    expect(find.text('Clientes'), findsAtLeastNWidgets(1));
    expect(find.text('Productos'), findsAtLeastNWidgets(1));
  });
}
