import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/payment_day_boundary_candidate.dart';

void main() {
  test('unverified holds labelled fake uses without invoking callbacks', () {
    const boundary = PaymentDayUnverifiedBoundaryCandidate();
    final legacyData = <String, int>{'previous-owner': 27};
    var calls = 0;
    for (final use in PaymentDayDependentUse.values) {
      final result = boundary.hold<Map<String, int>>(use, () {
        calls++;
        return Map.of(legacyData);
      });
      expect(result, isA<PaymentDayHeld<Map<String, int>>>());
    }
    expect(calls, 0);
    expect(legacyData, {'previous-owner': 27});
  });

  test('held has a distinct type from a confirmed empty map', () {
    const boundary = PaymentDayUnverifiedBoundaryCandidate();
    final held = boundary.hold<Map<String, int>>(
      PaymentDayDependentUse.forecast,
      () => <String, int>{},
    );
    final confirmedEmpty = <String, int>{};
    expect(held, isA<PaymentDayHeld<Map<String, int>>>());
    expect(confirmedEmpty, isEmpty);
    expect(held, isNot(equals(confirmedEmpty)));
  });
}
