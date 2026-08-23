import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/tiger_review_lane_status.dart';
import 'package:my_web_app/models/tiger_reviewer_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'parses the complete evidence-labelled reviewer profile catalog',
    () async {
      final source = await rootBundle.loadString(
        'assets/data/tiger_reviewer_profiles.json',
      );
      final catalog = TigerReviewerProfileCatalog.fromJsonString(source);

      expect(catalog.schemaVersion, 2);
      expect(catalog.profilesBySeat, hasLength(125));
      expect(catalog.enrichmentRound, 2);
      expect(catalog.averageProfileCompletenessPercent, greaterThan(0));
      expect(catalog.averageReviewReflectionPercent, greaterThan(0));
      expect(catalog.verifiedBirthDates, 2);
      expect(catalog.nextBatchNames, hasLength(5));
      expect(catalog.profilesBySeat.keys.toSet(), hasLength(125));
      expect(
        catalog.profilesBySeat.values.every(
          (profile) =>
              profile.name.isNotEmpty &&
              profile.companyRole.isNotEmpty &&
              profile.businessSummary.isNotEmpty &&
              profile.businessDomains.isNotEmpty &&
              profile.profileCompletenessPercent > 0 &&
              profile.reviewReflectionPercent > 0 &&
              profile.reviewFocusLabels.isNotEmpty &&
              profile.reviewQuestions.isNotEmpty &&
              profile.profileUrl?.hasScheme == true,
        ),
        isTrue,
      );
      expect(
        catalog.profilesBySeat.values
            .where((profile) => profile.birthDate != null)
            .every((profile) => profile.birthDateSourceUrl?.hasScheme == true),
        isTrue,
      );

      final standingsSource = await rootBundle.loadString(
        'assets/data/tiger_reviewer_league_status.json',
      );
      final standings = TigerReviewLaneStatus.fromJsonString(standingsSource);
      for (final standing in standings.entries) {
        final seat = standing['seat'] as int;
        expect(catalog.profilesBySeat[seat]?.name, standing['name']);
      }

      final sengoku = catalog.profilesBySeat[118]!;
      expect(sengoku.name, '仙石実');
      expect(sengoku.ageLabel(DateTime(2026, 8, 23)), '52歳（2026年8月23日時点）');
      expect(sengoku.companyRole, contains('代表'));
      expect(sengoku.businessDomains, contains('法務・会計・士業'));
      expect(sengoku.profileCompletenessPercent, 65);
      expect(sengoku.reviewReflectionPercent, 50);
      expect(sengoku.reviewReflectionMode, 'profile_balanced');
    },
  );

  test('calculates age only from a verified birth date', () {
    final verified = TigerReviewerProfile(
      seat: 21,
      name: '遠藤 悠記',
      rosterStatus: 'current',
      birthDate: DateTime(1990, 3, 17),
      companyRole: '株式会社えん代表',
      businessSummary: '学習塾、美容エステサロン、顧問事業',
      businessDomains: const <String>['教育・スクール'],
      appearances: 64,
      investmentCount: 17,
      publicViewpointSummary: '',
      profileUrl: Uri.parse('https://reiwanotora.jp/tiger/endo-yuki/'),
      birthDateSourceUrl: Uri.parse('https://reiwanotora.jp/tiger/endo-yuki/'),
    );
    final unverified = TigerReviewerProfile(
      seat: 1,
      name: 'ドラゴン細井',
      rosterStatus: 'current',
      birthDate: null,
      companyRole: 'アマソラクリニック 院長',
      businessSummary: '美容クリニック',
      businessDomains: const <String>['美容・ウェルネス'],
      appearances: 151,
      investmentCount: 56,
      publicViewpointSummary: '',
      profileUrl: Uri.parse('https://reiwanotora.jp/tiger/hosoi-ryu/'),
      birthDateSourceUrl: null,
    );

    expect(verified.ageLabel(DateTime(2026, 8, 23)), '36歳（2026年8月23日時点）');
    expect(unverified.ageLabel(DateTime(2026, 8, 23)), '公開情報未確認');
  });
}
