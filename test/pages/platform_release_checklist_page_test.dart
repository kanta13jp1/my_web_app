import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/platform_release_checklist_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'platform_release_checklist_v1': jsonEncode(<String, Object>{
        'sharedScope': '',
        'notes': <String, String>{'Web': 'Chrome で確認'},
        'statuses': <String, String>{'Web': 'passed'},
      }),
    });
  });

  testWidgets('loading, clearing, and undoing restores a saved platform status', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlatformReleaseChecklistPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('確認済み'), findsOneWidget);
    await tester.tap(find.byTooltip('確認内容を空にする'));
    await tester.pump();
    expect(find.text('未確認'), findsNWidgets(3));

    await tester.tap(find.text('元に戻す'));
    await tester.pump();
    expect(find.text('確認済み'), findsOneWidget);
    expect(find.text('Chrome で確認'), findsOneWidget);
  });
}
