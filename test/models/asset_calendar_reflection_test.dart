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
      () => AssetCalendarReflection.fromJson({
        ...fixture(),
        'linked_flow_id': 'bad',
      }),
      throwsFormatException,
    );
  });
  test(
    'flow projection requires explicit context and never infers reading',
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
      final event = AssetCalendarReflection.fromFlows([
        flow('外食 ビールを含む'),
      ]).single;
      expect(event.kinds, {
        AssetReflectionKind.dining,
        AssetReflectionKind.drinkingOut,
      });
      expect(event.alcoholAmount, isNull);
      expect(AssetCalendarReflection.fromFlows([flow('酒購入')]).single.kinds, {
        AssetReflectionKind.alcoholPurchase,
      });
    },
  );

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
    },
  );
  test('alcohol cannot exceed total and negative amounts rejected', () {
    expect(
      () => AssetCalendarReflection.fromJson({
        ...fixture(),
        'verified_amount': -1,
      }),
      throwsFormatException,
    );
    expect(
      () => AssetCalendarReflection.fromJson({
        ...fixture(),
        'verified_amount': 100,
        'alcohol_amount': 200,
      }),
      throwsFormatException,
    );
  });
  test('tobacco purchases include mixed receipts but exclude declarations', () {
    Map<String, dynamic> flow(String text, {String type = 'expense'}) => {
          'id': 77,
          'occurred_at': '2026-10-07T12:00:00',
          'action_type': type,
          'description': text,
          'amount': 1380,
        };
    for (final text in [
      'セブン：マールボロBOX（たばこ代）',
      '食品760円・タバコ620円',
      '煙草を購入',
      '禁煙中に煙草を買ってしまった',
      'Marlboro BOX',
      '外食・酒購入・たばこ620円',
    ]) {
      final event = AssetCalendarReflection.fromFlows([flow(text)]).single;
      expect(event.kinds, contains(AssetReflectionKind.tobaccoPurchase));
      expect(event.verifiedAmount, 1380);
      expect(event.sourceKey, 'flow:77');
    }
    for (final text in [
      'たばこがなくなったので禁煙を開始する',
      'たばこは買わなかった',
      'たばこ購入なし',
      '禁煙の本（書籍）',
      '食品だけを購入',
    ]) {
      expect(AssetCalendarReflection.fromFlows([flow(text)]), isEmpty);
    }
    expect(
      AssetCalendarReflection.fromFlows([flow('たばこ購入', type: 'transfer')]),
      isEmpty,
    );
    final mixed = AssetCalendarReflection.fromFlows([
      flow('外食・酒購入・たばこ620円'),
    ]).single;
    expect(
      mixed.kinds,
      containsAll([
        AssetReflectionKind.dining,
        AssetReflectionKind.alcoholPurchase,
        AssetReflectionKind.tobaccoPurchase,
      ]),
    );
    final summary = AssetReflectionSummary([mixed, mixed]);
    expect(summary.days(AssetReflectionKind.tobaccoPurchase), 1);
    expect(summary.knownAmount, 1380);
    expect(
      () => AssetCalendarReflection.fromJson(mixed.toJson()),
      throwsFormatException,
    );
  });

  test('linked diary observation preserves tobacco marker once', () {
    final recorded = AssetCalendarReflection(
      sourceKey: 'diary:one',
      linkedFlowId: '77',
      date: DateTime(2026, 10, 7),
      kinds: {AssetReflectionKind.dining},
      title: 'Confirmed dining',
      sourceLabel: 'Diary',
      verifiedAmount: 1380,
    );
    final projected = AssetCalendarReflection(
      sourceKey: 'flow:77',
      linkedFlowId: '77',
      date: DateTime(2026, 10, 7),
      kinds: {AssetReflectionKind.tobaccoPurchase},
      title: 'Food and tobacco',
      sourceLabel: 'Expense',
      verifiedAmount: 1380,
    );
    final merged = AssetCalendarReflection.mergeSources(
      [recorded],
      [projected],
    );
    expect(merged, hasLength(1));
    expect(merged.single.title, 'Confirmed dining');
    expect(merged.single.memo, contains('Expense: Food and tobacco'));
    expect(merged.single.kinds, contains(AssetReflectionKind.tobaccoPurchase));
    expect(AssetReflectionSummary(merged).knownAmount, 1380);
  });
  test('mixed purchase keeps tobacco and excludes unrelated book or negation',
      () {
    bool tobacco(String description) => AssetCalendarReflection.fromFlows([
          {
            'id': '801',
            'action_type': 'expense',
            'occurred_at': '2026-10-19T01:01:00',
            'description': description,
            'amount': 620
          },
        ]).any((event) =>
            event.kinds.contains(AssetReflectionKind.tobaccoPurchase));
    expect(tobacco('書籍935円・たばこ購入620円'), isTrue);
    expect(tobacco('酒は未購入。たばこ購入620円'), isTrue);
    expect(tobacco('書籍 たばこの本'), isFalse);
    expect(tobacco('たばこ未購入'), isFalse);
    expect(tobacco('禁煙を開始した'), isFalse);
    expect(tobacco('禁煙を始めたが、たばこ購入620円'), isTrue);
  });
}
