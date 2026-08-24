import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/tiger_review_status.dart';

void main() {
  test('bundled Tiger review snapshot contains the full evolving league', () {
    final source = File(
      'assets/data/tiger_review_status.json',
    ).readAsStringSync();
    final snapshot = TigerReviewStatusSnapshot.fromJsonString(source);

    expect(snapshot.schemaVersion, 2);
    expect(snapshot.pool.total, 125);
    expect(snapshot.pool.eligible, 125);
    expect(snapshot.pool.eliminated, 0);
    expect(
      snapshot.pool.division1 +
          snapshot.pool.division2 +
          snapshot.pool.division3 +
          snapshot.pool.division4 +
          snapshot.pool.division5,
      snapshot.pool.total,
    );
    expect(snapshot.coursePool.total, snapshot.courses.length);
    expect(snapshot.courses, isNotEmpty);
    expect(snapshot.featurePool.total, 13);
    expect(
      snapshot.featurePool.division1 +
          snapshot.featurePool.division2 +
          snapshot.featurePool.division3 +
          snapshot.featurePool.division4 +
          snapshot.featurePool.division5,
      snapshot.featurePool.total,
    );
    expect(snapshot.features, hasLength(13));
    expect(snapshot.reviewers, hasLength(125));
    expect(
      snapshot.reviewers.map((reviewer) => reviewer.seat).toSet(),
      hasLength(125),
    );
    expect(snapshot.publicationState, 'latest_cycle');
    expect(snapshot.latestCycle, isNotNull);
    expect(snapshot.latestCycle!.courseReview, isNotNull);
    expect(snapshot.latestCycle!.featureReview, isNotNull);
  });
}
