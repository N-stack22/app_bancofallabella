import 'package:bancofalabella_app2/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Supabase advisor login', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    await tester.pumpAndSettle();

    expect(find.text('Ingresar como asesor'), findsOneWidget);
    expect(find.text('Codigo de empleado o correo'), findsOneWidget);
    expect(find.byIcon(Icons.badge_outlined), findsOneWidget);
  });
}
