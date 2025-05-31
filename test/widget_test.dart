// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eco_gestion/main.dart';

void main() {
  testWidgets('Application démarre correctement', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Vérifier que l'application démarre sans erreur
    // Vous pouvez ajouter des tests spécifiques à votre application ici
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
