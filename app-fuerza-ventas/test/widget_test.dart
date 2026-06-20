import 'package:bancofalabella_app2/pages/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows demo scoring dashboard', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomePage(demoMode: true, userEmail: 'alumno1@example.com'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fuerza de Ventas'), findsOneWidget);
    expect(find.textContaining('Modo demo activo'), findsOneWidget);
    expect(find.text('Cartera diaria'), findsWidgets);
    expect(find.byIcon(Icons.list_alt), findsOneWidget);
  });
}
