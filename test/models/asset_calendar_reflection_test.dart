import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_calendar_reflection.dart';

Map<String, dynamic> fixture({
  String key = 'diary:one',
  String date = '2026-01-02',
}) =>
    {
      'source_key': key,
      'occurred_on': date,
      'kinds': ['dining', 'drinkingOut'],
      'title': 'Test meal',
      'source_label': 'Test diary',
    };
void main() {
  test('numeric production flow ids roundtrip and deduplicate projections', () {
    final event = AssetCalendarReflection.fromJson({
      ...fixture(),
      'linked_flow_id': 333,
    });
    expect(event.linkedFlowId, '333');
    final restored = AssetCalendarReflection.fromJson(event.toJson());
    expect(restored.linkedFlowId, '333');
    expect(
      () => AssetCalendarReflection.fromJson(
        {...fixture(), 'linked_flow_id': 'bad'},
      ),
      throwsFormatException,
    );
  });
  test('flow projection requires explicit context and never infers reading',
      () {
    Map<String, dynamic> flow(String title) => {
          'id': '333',
          'occurred_at': '2026-01-02T03:00:00Z',
          'action_type': 'expense',
          'description': title,
          'amount': 1000,
        };
    expect(AssetCalendarReflection.fromFlows([flow('本購入')]), isEmpty);
    expect(AssetCalendarReflection.fromFlows([flow('ビール')]), isEmpty);
    final event = AssetCalendarReflection.fromFlows([flow('外食 ビールを含む')]).single;
    expect(
      event.kinds,
      {AssetReflectionKind.dining, AssetReflectionKind.drinkingOut},
    );
    expect(event.alcoholAmount, isNull);
    expect(
      AssetCalendarReflection.fromFlows([flow('酒購入')]).single.kinds,
      {AssetReflectionKind.alcoholPurchase},
    );
  });

  test('unknown amounts remain null through roundtrip', () {
    final event = AssetCalendarReflection.fromJson(fixture());
    expect(event.verifiedAmount, isNull);
    expect(
      AssetCalendarReflection.fromJson(event.toJson()).alcoholAmount,
      isNull,
    );
    expect(AssetReflectionSummary([event]).unknownAmounts, 1);
  });
  test('rejects rolled over date and unsupported type', () {
    expect(
      () => AssetCalendarReflection.fromJson(fixture(date: '2026-02-30')),
      throwsFormatException,
    );
    expect(
      () => AssetCalendarReflection.fromJson({
        ...fixture(),
        'kinds': ['bookPurchase'],
      }),
      throwsFormatException,
    );
  });
  test('reading only contains confirmed optional pages and minutes', () {
    final event = AssetCalendarReflection.fromJson({
      ...fixture(),
      'kinds': ['reading'],
      'title': 'Test book',
      'pages': 12,
    });
    expect(event.minutes, isNull);
    expect(event.pages, 12);
    expect(AssetReflectionSummary([event]).days(AssetReflectionKind.dining), 0);
    expect(
      () => AssetCalendarReflection.fromJson({...fixture(), 'pages': 12}),
      throwsFormatException,
    );
  });
  test(
      'summary deduplicates days and linked financial amount without summing twice',
      () {
    const flow = '333';
    final first = AssetCalendarReflection.fromJson({
      ...fixture(),
      'verified_amount': 1000,
      'alcohol_amount': 300,
      'linked_flow_id': flow,
    });
    final second = AssetCalendarReflection.fromJson({
      ...fixture(key: 'receipt:one'),
      'verified_amount': 1000,
      'linked_flow_id': flow,
    });
    final summary = AssetReflectionSummary([first, second]);
    expect(summary.days(AssetReflectionKind.dining), 1);
    expect(summary.days(AssetReflectionKind.drinkingOut), 1);
    expect(summary.knownAmount, 1000);
  });
  test('alcohol cannot exceed total and negative amounts rejected', () {
    expect(
      () => AssetCalendarReflection.fromJson(
        {...fixture(), 'verified_amount': -1},
      ),
      throwsFormatException,
    );
    expect(
      () => AssetCalendarReflection.fromJson(
        {...fixture(), 'verified_amount': 100, 'alcohol_amount': 200},
      ),
      throwsFormatException,
    );
  });
}
