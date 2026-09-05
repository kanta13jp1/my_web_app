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
      expect(catalog.enrichmentRound, greaterThanOrEqualTo(12));
      expect(catalog.averageProfileCompletenessPercent, greaterThan(0));
      expect(catalog.averageReviewReflectionPercent, greaterThan(0));
      expect(catalog.verifiedBirthDates, 12);
      expect(catalog.nextBatchNames, hasLength(5));
      expect(
        catalog.nextBatchNames,
        <String>['渡正行', '足立暢', '泉舞', '日熊秀貴', '井川 意高'],
      );
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
      final yoshino = catalog.profilesBySeat[66]!;
      expect(yoshino.companyRole, contains('2023年11月時点'));
      expect(yoshino.profileCompletenessPercent, 56);
      expect(yoshino.reviewReflectionPercent, 58);
      expect(yoshino.reviewReflectionMode, 'profile_balanced');
      expect(yoshino.evidenceLinks, hasLength(2));

      final yamasawa = catalog.profilesBySeat[68]!;
      expect(yamasawa.companyRole, '株式会社FIT PLACE 代表取締役');
      expect(yamasawa.profileCompletenessPercent, 73);
      expect(yamasawa.reviewReflectionPercent, 83);
      expect(yamasawa.reviewReflectionMode, 'profile_guided');
      expect(yamasawa.evidenceLinks, hasLength(3));

      final adachi = catalog.profilesBySeat[97]!;
      expect(adachi.businessSummary, contains('豚骨ラーメン店'));
      expect(adachi.reviewReflectionMode, 'neutral_guarded');
      expect(adachi.evidenceLinks, hasLength(2));
      for (final seat in <int>[117, 120, 121]) {
        final profile = catalog.profilesBySeat[seat]!;
        expect(profile.profileCompletenessPercent, greaterThanOrEqualTo(62));
        expect(profile.reviewReflectionPercent, greaterThanOrEqualTo(68));
        expect(profile.reviewReflectionMode, isNot('neutral_guarded'));
      }
      for (final seat in <int>[119, 123, 124, 125]) {
        final profile = catalog.profilesBySeat[seat]!;
        expect(profile.profileCompletenessPercent, greaterThanOrEqualTo(62));
        expect(profile.reviewReflectionPercent, greaterThanOrEqualTo(68));
        expect(profile.reviewReflectionMode, 'profile_balanced');
        expect(profile.evidenceLinks.length, greaterThanOrEqualTo(2));
      }
      for (final seat in <int>[87, 88, 89, 91]) {
        final profile = catalog.profilesBySeat[seat]!;
        expect(profile.profileCompletenessPercent, greaterThanOrEqualTo(65));
        expect(profile.reviewReflectionPercent, 72);
        expect(profile.reviewReflectionMode, 'profile_balanced');
        expect(profile.evidenceLinks.length, greaterThanOrEqualTo(2));
      }
      final hasebe = catalog.profilesBySeat[87]!;
      expect(hasebe.ageLabel(DateTime(2026, 8, 26)), '51歳（2026年8月26日時点）');
      expect(hasebe.companyRole, contains('代表取締役会長'));
      final hikaru = catalog.profilesBySeat[89]!;
      expect(hikaru.ageLabel(DateTime(2026, 8, 26)), '35歳（2026年8月26日時点）');
      expect(hikaru.companyRole, contains('2025年12月'));
      final watari = catalog.profilesBySeat[116]!;
      expect(watari.ageLabel(DateTime(2026, 8, 26)), '公開情報未確認');
      expect(watari.reviewReflectionMode, 'neutral_guarded');
      expect(watari.evidenceLinks, hasLength(2));
      final rokugawa = catalog.profilesBySeat[106]!;
      expect(rokugawa.ageLabel(DateTime(2026, 9, 1)), '39歳（2026年9月1日時点）');
      expect(rokugawa.companyRole, contains('代表取締役'));
      expect(rokugawa.businessDomains, contains('不動産・建設・住宅'));
      expect(rokugawa.profileCompletenessPercent, 91);
      expect(rokugawa.reviewReflectionPercent, 88);
      expect(rokugawa.reviewReflectionMode, 'profile_guided');
      expect(rokugawa.evidenceLinks, hasLength(3));
      final okada = catalog.profilesBySeat[107]!;
      expect(okada.ageLabel(DateTime(2026, 9, 1)), '33歳（2026年9月1日時点）');
      expect(okada.companyRole, contains('代表・創業者'));
      expect(okada.profileCompletenessPercent, 85);
      expect(okada.reviewReflectionPercent, 79);
      expect(okada.reviewReflectionMode, 'profile_balanced');
      expect(okada.evidenceLinks, hasLength(3));
      final hiroyuki = catalog.profilesBySeat[108]!;
      expect(hiroyuki.ageLabel(DateTime(2026, 9, 2)), '公開情報未確認');
      expect(hiroyuki.companyRole, contains('4chan管理人'));
      expect(hiroyuki.businessDomains, contains('IT・SaaS・プラットフォーム'));
      expect(hiroyuki.profileCompletenessPercent, 58);
      expect(hiroyuki.reviewReflectionPercent, 61);
      expect(hiroyuki.reviewReflectionMode, 'profile_balanced');
      expect(hiroyuki.evidenceLinks, hasLength(2));
      final goto = catalog.profilesBySeat[110]!;
      expect(goto.ageLabel(DateTime(2026, 9, 2)), '公開情報未確認');
      expect(goto.companyRole, contains('事業再生版令和の虎 主宰'));
      expect(goto.businessDomains, contains('M&A・事業再生'));
      expect(goto.profileCompletenessPercent, 70);
      expect(goto.reviewReflectionPercent, 79);
      expect(goto.reviewReflectionMode, 'profile_balanced');
      expect(goto.evidenceLinks, hasLength(2));
      for (final seat in <int>[92, 94, 95, 96]) {
        final profile = catalog.profilesBySeat[seat]!;
        expect(profile.profileCompletenessPercent, greaterThanOrEqualTo(65));
        expect(profile.reviewReflectionPercent, 72);
        expect(profile.reviewReflectionMode, 'profile_balanced');
        expect(profile.evidenceLinks.length, greaterThanOrEqualTo(2));
      }
      final kaneko = catalog.profilesBySeat[92]!;
      expect(kaneko.ageLabel(DateTime(2026, 8, 28)), '54歳（2026年8月28日時点）');
      expect(kaneko.companyRole, contains('株式会社KANEKO'));
      final tomura = catalog.profilesBySeat[94]!;
      expect(tomura.ageLabel(DateTime(2026, 8, 28)), '32歳（2026年8月28日時点）');
      expect(tomura.companyRole, contains('hackjpn'));
      final murakawa = catalog.profilesBySeat[95]!;
      expect(murakawa.ageLabel(DateTime(2026, 8, 28)), '公開情報未確認');
      expect(murakawa.companyRole, contains('代表取締役'));
      final makita = catalog.profilesBySeat[96]!;
      expect(makita.ageLabel(DateTime(2026, 8, 28)), '41歳（2026年8月28日時点）');
      expect(makita.companyRole, contains('代表取締役副社長'));
      final reuter = catalog.profilesBySeat[98]!;
      expect(reuter.ageLabel(DateTime(2026, 8, 29)), '公開情報未確認');
      expect(reuter.companyRole, contains('株式会社Reuter'));
      expect(reuter.businessDomains, contains('人材・採用・組織'));
      expect(reuter.reviewReflectionPercent, 72);
      expect(reuter.reviewReflectionMode, 'profile_balanced');
      expect(reuter.evidenceLinks, hasLength(1));
      final aizawa = catalog.profilesBySeat[99]!;
      expect(aizawa.ageLabel(DateTime(2026, 8, 29)), '37歳（2026年8月29日時点）');
      expect(aizawa.companyRole, contains('株式会社VOYAGE'));
      expect(aizawa.businessDomains, contains('マーケティング・メディア'));
      expect(aizawa.profileCompletenessPercent, 80);
      expect(aizawa.reviewReflectionPercent, 72);
      expect(aizawa.reviewReflectionMode, 'profile_balanced');
      expect(aizawa.evidenceLinks, hasLength(3));
      final kawahara = catalog.profilesBySeat[104]!;
      expect(kawahara.ageLabel(DateTime(2026, 8, 30)), '62歳（2026年8月30日時点）');
      expect(kawahara.companyRole, contains('なんでんかんでん社長'));
      expect(kawahara.profileCompletenessPercent, 80);
      expect(kawahara.reviewReflectionPercent, 72);
      expect(kawahara.reviewReflectionMode, 'profile_balanced');
      expect(kawahara.evidenceLinks, hasLength(2));
      final yasuda = catalog.profilesBySeat[105]!;
      expect(yasuda.ageLabel(DateTime(2026, 8, 30)), '公開情報未確認');
      expect(yasuda.companyRole, contains('代表取締役社長'));
      expect(yasuda.profileCompletenessPercent, 65);
      expect(yasuda.reviewReflectionPercent, 72);
      expect(yasuda.reviewReflectionMode, 'profile_balanced');
      expect(yasuda.evidenceLinks, hasLength(3));
      final kataishi = catalog.profilesBySeat[125]!;
      expect(kataishi.ageLabel(DateTime(2026, 8, 25)), '32歳（2026年8月25日時点）');
      expect(
        kataishi.evidenceLinks.map((link) => link.label),
        contains('生年月日（東証提出資料）'),
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
      evidenceLinks: <TigerReviewerEvidenceLink>[
        TigerReviewerEvidenceLink(
          label: '肩書き・事業内容',
          url: Uri.parse('https://example.com/company'),
        ),
      ],
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
    expect(verified.evidenceLinks.single.label, '肩書き・事業内容');
    expect(verified.evidenceLinks.single.url.host, 'example.com');
    expect(unverified.ageLabel(DateTime(2026, 8, 23)), '公開情報未確認');
  });
}
