import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home calendar batches abstinence daily status reads', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final normalized = source.replaceAll('\r\n', '\n');
    final loaderStart = normalized.indexOf(
      'Future<List<_HomeCalendarDay>> _loadCalendarDays',
    );
    final loaderEnd = normalized.indexOf('\n  }\n', loaderStart);

    expect(loaderStart, greaterThanOrEqualTo(0));
    expect(loaderEnd, greaterThan(loaderStart));

    final loaderSource = normalized.substring(loaderStart, loaderEnd);
    expect(loaderSource, contains('AbstinenceGuardStore.loadSnapshotsByDate'));
    expect(loaderSource, isNot(contains('AbstinenceGuardStore.loadSnapshot(')));

    const helperPath = 'lib/utils/home_calendar_day_composition.dart';
    final helperSource = File(helperPath).readAsStringSync();
    expect(helperSource, contains('fetchAbstinenceByDate'));
    expect(helperSource, isNot(contains('AbstinenceGuardStore.loadSnapshot(')));
  });
}
