import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/tiger_review_status.dart';

void main() {
  test('bundled Tiger review snapshot contains the full initial league', () {
    final source = File(
      'assets/data/tiger_review_status.json',
    ).readAsStringSync();
    final snapshot = TigerReviewStatusSnapshot.fromJsonString(source);

    expect(snapshot.schemaVersion, 2);
    expect(snapshot.pool.total, 125);
    expect(snapshot.pool.eligible, 125);
    expect(snapshot.pool.eliminated, 0);
    expect(snapshot.pool.division3, 125);
    expect(snapshot.coursePool.total, 0);
    expect(snapshot.courses, isEmpty);
    expect(snapshot.featurePool.total, 13);
    expect(snapshot.featurePool.division3, 13);
    expect(snapshot.features, hasLength(13));
    expect(snapshot.reviewers, hasLength(125));
    expect(snapshot.latestCycle, isNull);
  });
}
