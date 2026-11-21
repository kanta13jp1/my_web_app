import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_external_points.dart';
import 'package:my_web_app/services/asset_external_points_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingSavePrefs extends Fake implements SharedPreferences {
  @override
  Future<bool> setString(String key, String value) async => false;
}

AssetExternalPointRecord _keioRecord({
  String id = 'ep_keio_1',
  DateTime? observedAt,
}) {
  return AssetExternalPointRecord(
    id: id,
    programName: AssetExternalPointPresets.keio,
    observedAt: observedAt ?? DateTime(2026, 11, 21, 14, 30),
    balanceAfter: 94,
    deltaPoints: 28,
    balanceBefore: 66,
    expiringPoints: 30,
    expiresOn: DateTime(2027, 4, 30),
    merchant: '紀伊國屋書店 府中店',
    pointTargetAmountYen: 970,
    memo: 'レシート控え',
  );
}

AssetExternalPointRecord _vPointRecord({
  String id = 'ep_vpoint_1',
  DateTime? observedAt,
}) {
  return AssetExternalPointRecord(
    id: id,
    programName: 'Vポイント',
    observedAt: observedAt ?? DateTime(2026, 11, 21, 18, 15),
    balanceAfter: 951,
    deltaPoints: 5,
    balanceBefore: 946,
    merchant: 'ファミリーマート',
    memo: '残高確認',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('AssetExternalPointsStore sign-in guard and isolation', () {
    test('throws StateError when ownerId is null, empty, or whitespace', () async {
      final prefs = await SharedPreferences.getInstance();
      const stores = <AssetExternalPointsStore>[
        AssetExternalPointsStore.forOwner(null),
        AssetExternalPointsStore.forOwner(''),
        AssetExternalPointsStore.forOwner('   '),
      ];

      for (final store in stores) {
        expect(() => store.storageKey, throwsStateError);
        await expectLater(store.hasSavedSetting(prefs: prefs), throwsStateError);
        await expectLater(store.load(prefs: prefs), throwsStateError);
        await expectLater(
          store.save(const <AssetExternalPointRecord>[], prefs: prefs),
          throwsStateError,
        );
      }
    });

    test('trims and encodes ownerId in storageKey', () {
      expect(
        const AssetExternalPointsStore.forOwner('  owner-a  ').storageKey,
        'asset_external_points_v1_owner-a',
      );
      expect(
        const AssetExternalPointsStore.forOwner('user/a+b').storageKey,
        'asset_external_points_v1_user%2Fa%2Bb',
      );
    });

    test('isolates saved records between owner A and owner B', () async {
      final prefs = await SharedPreferences.getInstance();
      const storeA = AssetExternalPointsStore.forOwner('owner-a');
      const storeB = AssetExternalPointsStore.forOwner('owner-b');

      await storeA.save(<AssetExternalPointRecord>[_keioRecord()], prefs: prefs);

      expect(await storeA.hasSavedSetting(prefs: prefs), isTrue);
      expect(await storeB.hasSavedSetting(prefs: prefs), isFalse);
      expect(await storeB.load(prefs: prefs), isEmpty);

      await storeB.save(
        <AssetExternalPointRecord>[_vPointRecord()],
        prefs: prefs,
      );

      final loadedA = await storeA.load(prefs: prefs);
      final loadedB = await storeB.load(prefs: prefs);

      expect(loadedA, hasLength(1));
      expect(loadedA.first.id, 'ep_keio_1');
      expect(loadedA.first.programName, AssetExternalPointPresets.keio);
      expect(loadedA.first.balanceAfter, 94);

      expect(loadedB, hasLength(1));
      expect(loadedB.first.id, 'ep_vpoint_1');
      expect(loadedB.first.programName, 'Vポイント');
      expect(loadedB.first.balanceAfter, 951);
    });

    test('preserves empty list deletion with hasSavedSetting == true', () async {
      final prefs = await SharedPreferences.getInstance();
      const store = AssetExternalPointsStore.forOwner('owner-a');

      expect(await store.hasSavedSetting(prefs: prefs), isFalse);

      await store.save(<AssetExternalPointRecord>[_keioRecord()], prefs: prefs);
      expect(await store.hasSavedSetting(prefs: prefs), isTrue);
      expect(await store.load(prefs: prefs), hasLength(1));

      await store.save(const <AssetExternalPointRecord>[], prefs: prefs);
      expect(await store.hasSavedSetting(prefs: prefs), isTrue);
      expect(await store.load(prefs: prefs), isEmpty);
    });

    test('throws StateError when SharedPreferences.setString returns false', () async {
      const store = AssetExternalPointsStore.forOwner('owner-a');
      await expectLater(
        store.save(
          const <AssetExternalPointRecord>[],
          prefs: _FailingSavePrefs(),
        ),
        throwsStateError,
      );
    });

    test('tolerates corrupted local storage payload', () async {
      const store = AssetExternalPointsStore.forOwner('owner-a');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(store.storageKey, '{not-valid-json');

      expect(await store.hasSavedSetting(prefs: prefs), isFalse);
      expect(await store.load(prefs: prefs), isEmpty);
    });
  });

  group('AssetExternalPointsStore encodeMirrorValue / decodeMirrorValue', () {
    test('round-trips empty records list', () {
      final encoded = AssetExternalPointsStore.encodeMirrorValue(
        const <AssetExternalPointRecord>[],
      );
      expect(encoded['version'], 1);
      expect(encoded['records'], isEmpty);
      expect(AssetExternalPointsStore.decodeMirrorValue(encoded), isEmpty);
    });

    test('round-trips Keio and V-Point records sorted newest first', () {
      final keio = _keioRecord();
      final vPoint = _vPointRecord();
      final encoded = AssetExternalPointsStore.encodeMirrorValue(
        <AssetExternalPointRecord>[keio, vPoint],
      );

      expect(encoded['version'], 1);
      final rawRecords = encoded['records'] as List<dynamic>;
      expect(rawRecords, hasLength(2));

      final decoded = AssetExternalPointsStore.decodeMirrorValue(encoded);
      expect(decoded, hasLength(2));
      expect(decoded.map((e) => e.id).toList(), <String>[
        'ep_vpoint_1',
        'ep_keio_1',
      ]);

      final decodedVPoint = decoded.first;
      expect(decodedVPoint.programName, 'Vポイント');
      expect(decodedVPoint.balanceAfter, 951);
      expect(decodedVPoint.deltaPoints, 5);
      expect(decodedVPoint.balanceBefore, 946);
      expect(decodedVPoint.merchant, 'ファミリーマート');

      final decodedKeio = decoded.last;
      expect(decodedKeio.programName, AssetExternalPointPresets.keio);
      expect(
        decodedKeio.observedAt.isAtSameMomentAs(keio.observedAt),
        isTrue,
      );
      expect(decodedKeio.balanceAfter, 94);
      expect(decodedKeio.deltaPoints, 28);
      expect(decodedKeio.balanceBefore, 66);
      expect(decodedKeio.expiringPoints, 30);
      expect(decodedKeio.expiresOn?.year, 2027);
      expect(decodedKeio.expiresOn?.month, 4);
      expect(decodedKeio.expiresOn?.day, 30);
      expect(decodedKeio.merchant, '紀伊國屋書店 府中店');
      expect(decodedKeio.pointTargetAmountYen, 970);
      expect(decodedKeio.memo, 'レシート控え');
    });

    test('tolerates invalid shapes and skips malformed record entries', () {
      expect(AssetExternalPointsStore.decodeMirrorValue(null), isEmpty);
      expect(AssetExternalPointsStore.decodeMirrorValue('oops'), isEmpty);
      expect(
        AssetExternalPointsStore.decodeMirrorValue(<String, dynamic>{
          'version': 1,
          'records': 'not-a-list',
        }),
        isEmpty,
      );

      final valid = _keioRecord();
      final decoded = AssetExternalPointsStore.decodeMirrorValue(
        <String, dynamic>{
          'version': 1,
          'records': <dynamic>[
            null,
            'bad-entry',
            <String, dynamic>{
              'id': '',
              'programName': AssetExternalPointPresets.keio,
              'observedAt': '2026-11-21T14:30:00',
              'balanceAfter': 94,
            },
            <String, dynamic>{
              'id': 'negative-balance',
              'programName': AssetExternalPointPresets.keio,
              'observedAt': '2026-11-21T14:30:00',
              'balanceAfter': -1,
            },
            valid.toJson(),
          ],
        },
      );

      expect(decoded, hasLength(1));
      expect(decoded.first.id, valid.id);
    });
  });

  group('AssetExternalPointsStore decodeOwnedMirrorRow', () {
    test('returns decoded records only when row user_id matches non-empty owner', () {
      final row = <String, dynamic>{
        'user_id': 'owner-a',
        'value': AssetExternalPointsStore.encodeMirrorValue(
          <AssetExternalPointRecord>[_keioRecord()],
        ),
      };

      final matched = AssetExternalPointsStore.decodeOwnedMirrorRow(
        row,
        'owner-a',
      );
      expect(matched, isNotNull);
      expect(matched, hasLength(1));
      expect(matched?.first.id, 'ep_keio_1');

      expect(
        AssetExternalPointsStore.decodeOwnedMirrorRow(row, 'owner-b'),
        isNull,
      );
      expect(
        AssetExternalPointsStore.decodeOwnedMirrorRow(
          <String, dynamic>{'value': row['value']},
          'owner-a',
        ),
        isNull,
      );
      expect(
        AssetExternalPointsStore.decodeOwnedMirrorRow(
          <String, dynamic>{'user_id': '', 'value': row['value']},
          '',
        ),
        isNull,
      );
      expect(
        AssetExternalPointsStore.decodeOwnedMirrorRow(
          <String, dynamic>{'user_id': '   ', 'value': row['value']},
          '   ',
        ),
        isNull,
      );
    });
  });
}
