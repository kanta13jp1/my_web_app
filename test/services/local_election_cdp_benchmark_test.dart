import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/local_election_plan.dart';
import 'package:my_web_app/services/local_election_cdp_benchmark.dart';

LocalElectionPrefecturePlan _pref(String name, {required int cdp}) {
  return LocalElectionPrefecturePlan(
    prefecture: name,
    region: 'テスト',
    additionalSeatTarget: 0,
    incumbentRetentionTarget: 0,
    focusMunicipalityCount: 0,
    newCandidateTarget: 0,
    endorsementDeadlineMonth: '2026-10',
    closeRaceSupportRounds: 0,
    currentMembers: 1,
    cdpLocalMembers: cdp,
  );
}

LocalElectionPlanDashboard _dashboard(
  List<LocalElectionPrefecturePlan> prefectures,
) {
  return LocalElectionPlanDashboard(
    currentLocalMembers: 0,
    targetLocalMembers: 700,
    previousUnifiedElectionWins: 0,
    previousUnifiedElectionFirstHalfWins: 0,
    previousUnifiedElectionSecondHalfWins: 0,
    updatedAt: DateTime(2026),
    prefectures: prefectures,
  );
}

void main() {
  group('LocalElectionCdpBenchmark.parse', () {
    test('extracts positive prefecture counts', () {
      final result = LocalElectionCdpBenchmark.parse(
        '{"prefectures":{"東京":56,"北海道":57}}',
      );
      expect(result, <String, int>{'東京': 56, '北海道': 57});
    });

    test('drops non-positive and keeps only valid entries', () {
      final result = LocalElectionCdpBenchmark.parse(
        '{"prefectures":{"東京":56,"沖縄":0,"foo":-3}}',
      );
      expect(result, <String, int>{'東京': 56});
    });

    test('returns an empty map for malformed or shapeless JSON', () {
      expect(LocalElectionCdpBenchmark.parse('not json'), isEmpty);
      expect(LocalElectionCdpBenchmark.parse('{"x":1}'), isEmpty);
    });
  });

  group('LocalElectionPlanDashboard.withCdpLocalMembers', () {
    test('overrides the seed value when a positive count is provided', () {
      final dashboard = _dashboard(<LocalElectionPrefecturePlan>[
        _pref('東京', cdp: 50),
      ]);
      final updated = dashboard.withCdpLocalMembers(<String, int>{'東京': 56});
      expect(updated.prefectures.single.cdpLocalMembers, 56);
    });

    test('keeps the seed value when absent or non-positive', () {
      final dashboard = _dashboard(<LocalElectionPrefecturePlan>[
        _pref('東京', cdp: 50),
        _pref('沖縄', cdp: 3),
      ]);
      final updated = dashboard.withCdpLocalMembers(<String, int>{'沖縄': 0});
      expect(updated.prefectures[0].cdpLocalMembers, 50);
      expect(updated.prefectures[1].cdpLocalMembers, 3);
    });

    test('returns the same dashboard for an empty benchmark', () {
      final dashboard = _dashboard(<LocalElectionPrefecturePlan>[
        _pref('東京', cdp: 50),
      ]);
      final updated = dashboard.withCdpLocalMembers(const <String, int>{});
      expect(identical(updated, dashboard), isTrue);
    });
  });
}
