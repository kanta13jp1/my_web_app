import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/local_election_reality_service.dart';

void main() {
  test('accepts explicitly complete remote snapshots with no quality issues', () {
    expect(
      () => LocalElectionRealityService.validateRemoteSnapshotPayload(
        <String, dynamic>{
          'collectionQuality': <String, dynamic>{'complete': true, 'issues': <String>[]},
        },
      ),
      returnsNormally,
    );
  });

  test('member counts cannot make incomplete candidate observations complete', () {
    expect(
      () => LocalElectionRealityService.validateRemoteSnapshotPayload(
        <String, dynamic>{
          'officialCurrentLocalMembers': 416,
          'upcomingSchedules': <dynamic>[],
          'collectionQuality': <String, dynamic>{
            'complete': false,
            'issues': <String>['official_candidate_vote_date_unverified:49'],
          },
        },
      ),
      throwsFormatException,
    );
  });

  test('missing or malformed quality metadata fails closed', () {
    for (final quality in <dynamic>[null, 'complete', <String, dynamic>{},
      <String, dynamic>{'complete': true},
      <String, dynamic>{'complete': true, 'issues': 'none'}]) {
      expect(
        () => LocalElectionRealityService.validateRemoteSnapshotPayload(
          <String, dynamic>{'collectionQuality': quality},
        ),
        throwsFormatException,
      );
    }
  });

  test('non-empty issues cannot be hidden by a complete flag', () {
    expect(
      () => LocalElectionRealityService.validateRemoteSnapshotPayload(
        <String, dynamic>{
          'collectionQuality': <String, dynamic>{
            'complete': true, 'issues': <String>['prefecture_fetch_failed:東京都'],
          },
        },
      ),
      throwsFormatException,
    );
  });
}
