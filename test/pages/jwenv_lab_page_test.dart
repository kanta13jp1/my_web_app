import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/jwenv_lab_page.dart';

void main() {
  testWidgets('JwenvLabPage renders title and stub view in VM test',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: JwenvLabPage(),
      ),
    );

    expect(find.text('Jwenv WebGPU Lab'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
