import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_external_points.dart';

void main() {
  group('AssetExternalPointPresets', () {
    test('defines Keio and standard Japanese point presets', () {
      expect(AssetExternalPointPresets.keio, '京王ポイント');
      expect(
        AssetExternalPointPresets.all,
        const <String>[
          '京王ポイント',
          'Vポイント',
          '楽天ポイント',
          'dポイント',
          'Pontaポイント',
          'PayPayポイント',
          'ファミマポイント',
          'JRE POINT',
        ],
      );
    });
  });

  group('AssetExternalPointRecord JSON & copyWith', () {
    test(
      'round-trips Keio point record and normalizes expiresOn to date-only',
      () {
        final record = AssetExternalPointRecord(
          id: 'keio-20261121-1',
          programName: AssetExternalPointPresets.keio,
          observedAt: DateTime(2026, 11, 21, 18, 30),
          balanceAfter: 105,
          deltaPoints: 25,
          balanceBefore: 80,
          expiringPoints: 20,
          expiresOn: DateTime(2027, 4, 29, 15, 45),
          merchant: 'サンプル書店',
          pointTargetAmountYen: 840,
          memo: '前年度20P期限確認',
        );

        final json = record.toJson();
        final restored = AssetExternalPointRecord.fromJson(json);

        expect(restored, isNotNull);
        expect(restored, record);
        expect(restored!.balanceAfter, 105);
        expect(restored.balanceBefore, 80);
        expect(restored.deltaPoints, 25);
        expect(restored.expiringPoints, 20);
        expect(restored.expiresOn, DateTime(2027, 4, 29));
        expect(restored.merchant, 'サンプル書店');
        expect(restored.pointTargetAmountYen, 840);
        expect(restored.memo, '前年度20P期限確認');
        expect(json['expiresOn'], '2027-04-29');
      },
    );

    test('copyWith updates fields and clears nullable fields when requested',
        () {
      final initial = AssetExternalPointRecord(
        id: 'keio-1',
        programName: AssetExternalPointPresets.keio,
        observedAt: DateTime(2026, 11, 21, 18, 30),
        balanceAfter: 105,
        deltaPoints: 25,
        balanceBefore: 80,
        expiringPoints: 20,
        expiresOn: DateTime(2027, 4, 29),
        pointTargetAmountYen: 840,
      );

      final updated = initial.copyWith(
        balanceAfter: 104,
        expiresOn: DateTime(2027, 5, 1, 22, 10),
        clearBalanceBefore: true,
      );
      expect(updated.balanceAfter, 104);
      expect(updated.balanceBefore, isNull);
      expect(updated.expiresOn, DateTime(2027, 5, 1));
      expect(updated.pointTargetAmountYen, 840);

      final cleared = updated.copyWith(
        clearExpiringPoints: true,
        clearExpiresOn: true,
        clearPointTargetAmountYen: true,
      );
      expect(cleared.expiringPoints, isNull);
      expect(cleared.expiresOn, isNull);
      expect(cleared.pointTargetAmountYen, isNull);
    });

    test(
        'fromJson tolerates invalid root, missing/invalid fields, and negative balance',
        () {
      const invalidRoots = <dynamic>[null, 'oops', 123, <dynamic>[]];
      for (final root in invalidRoots) {
        expect(AssetExternalPointRecord.fromJson(root), isNull);
      }

      final validBase = <String, dynamic>{
        'id': 'ep-1',
        'programName': 'Vポイント',
        'observedAt': '2026-11-21T19:00:00.000',
        'balanceAfter': 951,
      };
      expect(AssetExternalPointRecord.fromJson(validBase), isNotNull);

      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'id': '',
        }),
        isNull,
      );
      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'id': '   ',
        }),
        isNull,
      );
      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'id': 999,
        }),
        isNull,
      );
      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'programName': '',
        }),
        isNull,
      );
      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'programName': '   ',
        }),
        isNull,
      );
      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'observedAt': 'not-a-date',
        }),
        isNull,
      );
      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'observedAt': null,
        }),
        isNull,
      );
      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'balanceAfter': -1,
        }),
        isNull,
      );
      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'balanceAfter': 95.5,
        }),
        isNull,
      );
      expect(
        AssetExternalPointRecord.fromJson(<String, dynamic>{
          ...validBase,
          'balanceAfter': null,
        }),
        isNull,
      );

      final sanitized = AssetExternalPointRecord.fromJson(<String, dynamic>{
        ...validBase,
        'balanceBefore': -5,
        'expiringPoints': 0,
        'expiresOn': '2027-02-30',
        'pointTargetAmountYen': 0,
      });
      expect(sanitized, isNotNull);
      expect(sanitized!.balanceBefore, isNull);
      expect(sanitized.expiringPoints, isNull);
      expect(sanitized.expiresOn, isNull);
      expect(sanitized.pointTargetAmountYen, isNull);
    });
  });

  group('Sorting and program summarization', () {
    test('sorts by observedAt desc then id asc and summarizes programs', () {
      final keioOld = AssetExternalPointRecord(
        id: 'b-keio-old',
        programName: AssetExternalPointPresets.keio,
        observedAt: DateTime(2026, 11, 20, 10, 0),
        balanceAfter: 80,
      );
      final keioNew = AssetExternalPointRecord(
        id: 'a-keio-new',
        programName: AssetExternalPointPresets.keio,
        observedAt: DateTime(2026, 11, 21, 18, 30),
        balanceAfter: 105,
        deltaPoints: 25,
        balanceBefore: 80,
        expiringPoints: 20,
        expiresOn: DateTime(2027, 4, 29),
      );
      final vPoint = AssetExternalPointRecord(
        id: 'c-vpoint',
        programName: 'Vポイント',
        observedAt: DateTime(2026, 11, 21, 19, 0),
        balanceAfter: 951,
      );
      final rakutenA = AssetExternalPointRecord(
        id: 'rakuten-1',
        programName: '楽天ポイント',
        observedAt: DateTime(2026, 11, 19, 12, 0),
        balanceAfter: 200,
      );
      final rakutenB = AssetExternalPointRecord(
        id: 'rakuten-2',
        programName: '楽天ポイント',
        observedAt: DateTime(2026, 11, 19, 12, 0),
        balanceAfter: 300,
      );

      final records = <AssetExternalPointRecord>[
        keioOld,
        rakutenB,
        vPoint,
        keioNew,
        rakutenA,
      ];

      final sorted = sortExternalPointRecords(records);
      expect(
        sorted.map((record) => record.id).toList(),
        const <String>[
          'c-vpoint',
          'a-keio-new',
          'b-keio-old',
          'rakuten-1',
          'rakuten-2',
        ],
      );

      final summaries = summarizeExternalPointPrograms(
        records,
        now: DateTime(2026, 11, 21, 20, 0),
      );
      expect(summaries.length, 3);

      expect(summaries[0].programName, 'Vポイント');
      expect(summaries[0].latestRecord.balanceAfter, 951);
      expect(summaries[0].recordCount, 1);
      expect(summaries[0].expiryStatus, AssetExternalPointExpiryStatus.none);

      expect(summaries[1].programName, AssetExternalPointPresets.keio);
      expect(summaries[1].latestRecord.balanceAfter, 105);
      expect(summaries[1].recordCount, 2);
      expect(summaries[1].expiryStatus, AssetExternalPointExpiryStatus.active);

      expect(summaries[2].programName, '楽天ポイント');
      expect(summaries[2].latestRecord.id, 'rakuten-1');
      expect(summaries[2].recordCount, 2);
      expect(summaries[2].expiryStatus, AssetExternalPointExpiryStatus.none);
    });

    test('classifies all four expiryStatus boundaries accurately', () {
      final now = DateTime(2026, 11, 21, 23, 59);

      AssetExternalPointExpiryStatus statusFor({
        int? expiringPoints,
        DateTime? expiresOn,
      }) {
        final summary = summarizeExternalPointPrograms(
          <AssetExternalPointRecord>[
            AssetExternalPointRecord(
              id: 'test-1',
              programName: AssetExternalPointPresets.keio,
              observedAt: DateTime(2026, 11, 21, 18, 0),
              balanceAfter: 105,
              expiringPoints: expiringPoints,
              expiresOn: expiresOn,
            ),
          ],
          now: now,
        );
        return summary.single.expiryStatus;
      }

      expect(
        statusFor(expiringPoints: null, expiresOn: DateTime(2026, 11, 30)),
        AssetExternalPointExpiryStatus.none,
      );
      expect(
        statusFor(expiringPoints: 20, expiresOn: null),
        AssetExternalPointExpiryStatus.none,
      );
      expect(
        statusFor(expiringPoints: 0, expiresOn: DateTime(2026, 11, 30)),
        AssetExternalPointExpiryStatus.none,
      );

      expect(
        statusFor(expiringPoints: 20, expiresOn: DateTime(2026, 11, 20)),
        AssetExternalPointExpiryStatus.expired,
      );
      expect(
        statusFor(expiringPoints: 20, expiresOn: DateTime(2026, 11, 21)),
        AssetExternalPointExpiryStatus.expiringSoon,
      );
      expect(
        statusFor(expiringPoints: 20, expiresOn: DateTime(2026, 12, 21)),
        AssetExternalPointExpiryStatus.expiringSoon,
      );
      expect(
        statusFor(expiringPoints: 20, expiresOn: DateTime(2026, 12, 22)),
        AssetExternalPointExpiryStatus.active,
      );
    });
  });

  group('parseFlexiblePointInt and formatters', () {
    test('parses full-width digits, commas, whitespace, and units', () {
      expect(parseFlexiblePointInt('105'), 105);
      expect(parseFlexiblePointInt('１０５'), 105);
      expect(parseFlexiblePointInt('0'), 0);
      expect(parseFlexiblePointInt('1,250'), 1250);
      expect(parseFlexiblePointInt('１，２５０'), 1250);
      expect(parseFlexiblePointInt('　951 P　'), 951);
      expect(parseFlexiblePointInt('＋２５pt'), 25);
      expect(parseFlexiblePointInt('＋ 1,250 Ｐ'), 1250);
      expect(parseFlexiblePointInt('２５ｐｔ'), 25);
      expect(parseFlexiblePointInt('840円'), 840);
      expect(parseFlexiblePointInt('８４０ 円'), 840);
    });

    test('handles negative sign according to allowNegative flag', () {
      expect(parseFlexiblePointInt('-50'), isNull);
      expect(parseFlexiblePointInt('−５０P'), isNull);
      expect(parseFlexiblePointInt('ー50pt'), isNull);
      expect(parseFlexiblePointInt('－50円'), isNull);

      expect(parseFlexiblePointInt('-50', allowNegative: true), -50);
      expect(parseFlexiblePointInt('−５０P', allowNegative: true), -50);
      expect(parseFlexiblePointInt('ー５０pt', allowNegative: true), -50);
      expect(
        parseFlexiblePointInt('－ 1,250 円', allowNegative: true),
        -1250,
      );
    });

    test('returns null on malformed inputs', () {
      const malformed = <String>[
        '',
        '   ',
        'P',
        '+',
        '-',
        'abc',
        '12.5',
        '12pt3',
        '++10',
      ];
      for (final raw in malformed) {
        expect(parseFlexiblePointInt(raw, allowNegative: true), isNull);
      }
    });

    test('formats dates, datetimes, and comma-separated counts', () {
      expect(formatExternalPointDate(DateTime(2027, 4, 29)), '2027/04/29');
      expect(
        formatExternalPointDateTime(DateTime(2026, 11, 21, 9, 5)),
        '2026/11/21 09:05',
      );
      expect(formatExternalPointsCount(0), '0');
      expect(formatExternalPointsCount(105), '105');
      expect(formatExternalPointsCount(951), '951');
      expect(formatExternalPointsCount(1250), '1,250');
      expect(formatExternalPointsCount(1234567), '1,234,567');
      expect(formatExternalPointsCount(-1250), '-1,250');
    });
  });
}
