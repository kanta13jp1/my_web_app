import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/growth_mission_service.dart';

void main() {
  group('GrowthMissionService command center fallback', () {
    test('returns cross-functional brief when Supabase is unavailable',
        () async {
      const service = GrowthMissionService();
      final dashboard = GrowthMissionDashboard(
        totalRegisteredUsers: 2,
        todayRegistrations: 0,
        activeUsersToday: 1,
        liveRegisteredUsers: 1,
        liveGuestViewers: 1,
        todayLandingViews: 5,
        monthLandingViews: 18,
        totalLandingViews: 18,
        todayShares: 0,
        referralSnapshot: const ReferralGrowthSnapshot.empty(),
        acquisitionSnapshot: GrowthAcquisitionSnapshot.empty(),
        refreshedAt: DateTime(2026, 3, 23, 10),
      );

      final brief = await service.loadCommandCenterBrief(dashboard);

      expect(brief.stageLabel, 'Pre-PMF');
      expect(brief.focusTags, contains('public-memo-seo'));
      expect(brief.focusTags, contains('registration-bottleneck'));
      expect(brief.departments, hasLength(10));
      expect(
        brief.departments.map((department) => department.id),
        containsAll(<String>[
          'development',
          'product',
          'advertising',
          'pr',
          'sales',
          'marketing',
          'hr',
          'finance',
          'procurement',
          'business-planning',
        ]),
      );
    });

    test('moves to scale-up stage for larger user counts', () async {
      const service = GrowthMissionService();
      final dashboard = GrowthMissionDashboard(
        totalRegisteredUsers: 1200,
        todayRegistrations: 8,
        activeUsersToday: 33,
        liveRegisteredUsers: 15,
        liveGuestViewers: 6,
        todayLandingViews: 80,
        monthLandingViews: 900,
        totalLandingViews: 3000,
        todayShares: 12,
        referralSnapshot: const ReferralGrowthSnapshot.empty(),
        acquisitionSnapshot: GrowthAcquisitionSnapshot.empty(),
        refreshedAt: DateTime(2026, 3, 23, 12),
      );

      final brief = await service.loadCommandCenterBrief(dashboard);

      expect(brief.stageLabel, 'Scale-up');
      expect(
        brief.stageReason,
        contains('process'),
      );
    });

    test('buildInviteUrlForCode uses referral route and tracking params', () {
      final inviteUrl = GrowthMissionService.buildInviteUrlForCode('ABCD1234');
      final uri = Uri.parse(inviteUrl);

      expect(uri.path, '/referral');
      expect(uri.queryParameters['ref'], 'ABCD1234');
      expect(uri.queryParameters['utm_source'], 'referral');
      expect(uri.queryParameters['utm_medium'], 'invite');
      expect(uri.queryParameters['utm_campaign'], 'growth_mission');
      expect(uri.queryParameters['v'], 'test2025');
    });
  });
}
