import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/self_skill_asset.dart';
import 'package:my_web_app/services/self_skill_asset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SelfSkillAssetService validation (#2730)', () {
    test('validates skill name, level, experience years, period and progress',
        () {
      expect(SelfSkillAssetService.validateSkillName(''), isNotNull);
      expect(SelfSkillAssetService.validateSkillName('A'), isNotNull);
      expect(SelfSkillAssetService.validateSkillName('Flutter'), isNull);

      expect(SelfSkillAssetService.validateProficiencyLevel('0'), isNotNull);
      expect(SelfSkillAssetService.validateProficiencyLevel('6'), isNotNull);
      expect(SelfSkillAssetService.validateProficiencyLevel('4'), isNull);

      expect(SelfSkillAssetService.validateExperienceYears('-1'), isNotNull);
      expect(SelfSkillAssetService.validateExperienceYears('2.5'), isNull);
      expect(SelfSkillAssetService.validateExperienceYears(''), isNull);

      expect(SelfSkillAssetService.validateTargetPeriod('bad'), isNotNull);
      expect(SelfSkillAssetService.validateTargetPeriod('2026-12'), isNull);
      expect(SelfSkillAssetService.validateTargetPeriod('2026-Q4'), isNull);

      expect(SelfSkillAssetService.validateProgressPercent('101'), isNotNull);
      expect(SelfSkillAssetService.validateProgressPercent('75'), isNull);
    });
  });

  group('SelfSkillAssetService CRUD & summary (#1392 / #2770)', () {
    test('persists skills and acquisition targets separately by userScope',
        () async {
      var remoteSyncCalls = 0;
      final storageA = SharedPreferencesSelfSkillAssetStorage(
        userScope: 'user_a',
        onRemoteSync: (_) async {
          remoteSyncCalls++;
        },
      );
      final serviceA = SelfSkillAssetService(storage: storageA);
      final serviceB = SelfSkillAssetService(
        storage: SharedPreferencesSelfSkillAssetStorage(userScope: 'user_b'),
      );

      final s1 = SelfSkillAsset(
        id: 's1',
        name: 'Flutter UI',
        category: '技術・開発',
        proficiencyLevel: 5,
        experienceYears: 3.5,
        origin: SkillAssessmentOrigin.verifiedRecord,
        note: '本番Web開発実績',
        updatedAt: DateTime(2026, 6, 1),
      );
      final s2 = SelfSkillAsset(
        id: 's2',
        name: 'SQL設計',
        category: 'AI・データ',
        proficiencyLevel: 4,
        experienceYears: 2.0,
        origin: SkillAssessmentOrigin.selfDeclared,
        updatedAt: DateTime(2026, 6, 2),
      );
      final s3 = SelfSkillAsset(
        id: 's3',
        name: '事業計数',
        category: '事業・経営',
        proficiencyLevel: 3,
        experienceYears: 1.5,
        origin: SkillAssessmentOrigin.selfDeclared,
        updatedAt: DateTime(2026, 6, 3),
      );

      await serviceA.upsertSkill(s1);
      await serviceA.upsertSkill(s2);
      await serviceA.upsertSkill(s3);
      await serviceA.upsertTarget(
        SelfSkillTarget(
          id: 't1',
          skillName: '英語プレゼン',
          category: '語学・発信',
          targetLevel: 4,
          currentProgressPercent: 40,
          targetPeriod: '2026-Q4',
          investmentNote: '週3回オンライン演習',
          createdAt: DateTime(2026, 6, 1),
        ),
      );

      expect(remoteSyncCalls, 4);

      final loadedA = await serviceA.load();
      final loadedB = await serviceB.load();
      expect(loadedA.skills, hasLength(3));
      expect(loadedA.targets, hasLength(1));
      expect(loadedB.skills, isEmpty);

      final summary = SelfSkillAssetService.summarize(loadedA);
      expect(summary.totalSkills, 3);
      expect(summary.verifiedSkillsCount, 1);
      expect(summary.selfDeclaredSkillsCount, 2);
      expect(summary.averageProficiency, closeTo(4.0, 0.01));
      expect(summary.averageTargetProgress, closeTo(40.0, 0.01));
      expect(summary.radarAxes, hasLength(3));

      final afterDelete =
          await serviceA.deleteSkill('s2', currentData: loadedA);
      expect(afterDelete.skills, hasLength(2));
    });
  });
}
