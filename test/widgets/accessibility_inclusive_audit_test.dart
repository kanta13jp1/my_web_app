import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/user_profile.dart';
import 'package:my_web_app/pages/profile_settings_page.dart';
import 'package:my_web_app/widgets/inclusive_gender_selector.dart';

void main() {
  group('Accessibility & Inclusive Optional Profile Attributes (#2809)', () {
    test('UserProfile preserves optional nullable and diverse gender values',
        () {
      final now = DateTime.utc(2026, 11, 23);
      final omitted =
          UserProfile(userId: 'u_1', createdAt: now, updatedAt: now);
      expect(omitted.gender, isNull);
      expect(omitted.toJson()['gender'], isNull);

      final roundTripOmitted = UserProfile.fromJson(<String, dynamic>{
        'user_id': 'u_1',
        'gender': null,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      expect(roundTripOmitted.gender, isNull);

      final nonBinary = UserProfile.fromJson(<String, dynamic>{
        'user_id': 'u_2',
        'gender': 'ノンバイナリー',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
      expect(nonBinary.gender, 'ノンバイナリー');
    });

    for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
      testWidgets(
          'InclusiveGenderSelector passes contrast, tap-target, and semantics guidelines in ${brightness.name} mode at 2.0x scale',
          (tester) async {
        final handle = tester.ensureSemantics();
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        try {
          tester.view.physicalSize = const Size(1280, 1800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF4F46E5),
                  brightness: brightness,
                ),
                useMaterial3: true,
              ),
              home: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: InclusiveGenderSelector(controller: controller),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await expectLater(tester, meetsGuideline(textContrastGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull);
        } finally {
          handle.dispose();
        }
      });
    }

    testWidgets(
        'ProfileSettingsPage allows omitted, non-binary, and custom gender values with semantics',
        (tester) async {
      final handle = tester.ensureSemantics();
      try {
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final savedProfiles = <UserProfile>[];
        final seed = UserProfile(
          userId: 'debug-user',
          displayName: '監査ユーザー',
          gender: '女性',
          targetDeathAge: 80,
          createdAt: DateTime.utc(2026, 11, 23),
          updatedAt: DateTime.utc(2026, 11, 23),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ProfileSettingsPage(
              debugInitialProfile: seed,
              onDebugSave: (profile) async {
                savedProfiles.add(profile);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Selecting "回答しない" clears gender to null cleanly
        final unansweredChip =
            find.byKey(const Key('inclusive_gender_chip_回答しない'));
        await tester.ensureVisible(unansweredChip);
        await tester.tap(unansweredChip);
        await tester.pumpAndSettle();

        final saveBtn = find.text('プロフィールを保存');
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(savedProfiles.length, 1);
        expect(savedProfiles.last.gender, isNull);

        // 2. Selecting "ノンバイナリー" saves inclusive value cleanly
        final nonBinaryChip =
            find.byKey(const Key('inclusive_gender_chip_ノンバイナリー'));
        await tester.ensureVisible(nonBinaryChip);
        await tester.tap(nonBinaryChip);
        await tester.pumpAndSettle();

        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(savedProfiles.length, 2);
        expect(savedProfiles.last.gender, 'ノンバイナリー');

        // 3. Custom free-text self-description saves cleanly
        final genderInput =
            find.byKey(const Key('inclusive_gender_text_field'));
        await tester.ensureVisible(genderInput);
        await tester.enterText(genderInput, 'ジェンダーフルイド');
        await tester.pumpAndSettle();

        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(savedProfiles.length, 3);
        expect(savedProfiles.last.gender, 'ジェンダーフルイド');
        expect(tester.takeException(), isNull);
      } finally {
        handle.dispose();
      }
    });
  });
}
