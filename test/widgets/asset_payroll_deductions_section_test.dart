import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/widgets/asset_payroll_deductions_section.dart';

void main() {
  testWidgets('signed-out section creates no unhandled load future', (tester) async {
    final client = SupabaseClient('https://example.invalid', 'synthetic-public-key');
    addTearDown(client.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssetPayrollDeductionsSection(
            client: client,
            initialYear: 2030,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('給与の税金・社会保険料：ログイン後に表示します。'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
