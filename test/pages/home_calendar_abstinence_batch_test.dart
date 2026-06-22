import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home calendar batches abstinence daily status reads', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final loaderStart = source.indexOf(
      'Future<List<_HomeCalendarDay>> _loadCalendarDays',
    );
    final loaderEnd = source.indexOf(
      'String _buildRelapsePreventionAction',
      loaderStart,
    );

    expect(loaderStart, greaterThanOrEqualTo(0));
    expect(loaderEnd, greaterThan(loaderStart));

    final loaderSource = source.substring(loaderStart, loaderEnd);
    expect(loaderSource, contains('AbstinenceGuardStore.loadSnapshotsByDate'));
    expect(loaderSource, isNot(contains('AbstinenceGuardStore.loadSnapshot(')));
  });
}
