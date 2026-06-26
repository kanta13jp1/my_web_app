import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/terms_page.dart';
import 'package:my_web_app/pages/tokushoho_page.dart';

void main() {
  testWidgets('terms page renders the terms asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TermsPage(showBackButton: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Terms'), findsWidgets);
    expect(find.textContaining('Terms of Service'), findsWidgets);
    expect(find.textContaining('Paid Plans'), findsOneWidget);
  });

  testWidgets('tokushoho page renders the disclosure asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: TokushohoPage(showBackButton: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Commercial Disclosure'), findsWidgets);
    expect(
      find.textContaining('Specified Commercial Transactions'),
      findsWidgets,
    );
    expect(find.textContaining('{{OPERATOR_LEGAL_NAME}}'), findsWidgets);
  });
}
