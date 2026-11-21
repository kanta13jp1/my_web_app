import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_web_app/models/asset_external_points.dart';
import 'package:my_web_app/services/asset_external_points_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    balanceAfter: 105,
    deltaPoints: 25,
    balanceBefore: 80,
    expiringPoints: 20,
    expiresOn: DateTime(2027, 4, 29),
    merchant: 'サンプル書店',
    pointTargetAmountYen: 840,
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
    test('throws StateError when ownerId is null, empty, or whitespace',
        () async {
      final prefs = await SharedPreferences.getInstance();
      const stores = <AssetExternalPointsStore>[
        AssetExternalPointsStore.forOwner(null),
        AssetExternalPointsStore.forOwner(''),
        AssetExternalPointsStore.forOwner('   '),
      ];

      for (final store in stores) {
        expect(() => store.storageKey, throwsStateError);
        final hasSavedSetting = store.hasSavedSetting(prefs: prefs);
        await expectLater(hasSavedSetting, throwsStateError);
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

      await storeA
          .save(<AssetExternalPointRecord>[_keioRecord()], prefs: prefs);

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
      expect(loadedA.first.balanceAfter, 105);

      expect(loadedB, hasLength(1));
      expect(loadedB.first.id, 'ep_vpoint_1');
      expect(loadedB.first.programName, 'Vポイント');
      expect(loadedB.first.balanceAfter, 951);
    });

    test('preserves empty list deletion with hasSavedSetting == true',
        () async {
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

    test('throws StateError when SharedPreferences.setString returns false',
        () async {
      const store = AssetExternalPointsStore.forOwner('owner-a');
      await expectLater(
        store.save(
          const <AssetExternalPointRecord>[],
          prefs: _FailingSavePrefs(),
        ),
        throwsStateError,
      );
    });

    test('rejects a stale editor and preserves an explicit empty list',
        () async {
      const store = AssetExternalPointsStore.forOwner('owner-a');
      final keio = _keioRecord();
      final updated = _vPointRecord();

      expect(await store.saveIfUnchanged([keio], expected: []), isTrue);
      expect(await store.saveIfUnchanged([updated], expected: []), isFalse);
      expect(
        await store.saveIfUnchanged(
          [updated],
          expected: [keio],
          isCurrent: () => false,
        ),
        isFalse,
      );
      expect((await store.load()).single.id, keio.id);

      expect(await store.saveIfUnchanged([], expected: [keio]), isTrue);
      expect(
        await store.saveIfUnchanged([keio], expected: [], requireMissing: true),
        isFalse,
      );
      expect(await store.load(), isEmpty);
    });

    test(
      'serializes competing browser writes for the same owner',
      () async {
        const firstStore = AssetExternalPointsStore.forOwner('owner-a');
        const secondStore = AssetExternalPointsStore.forOwner('owner-a');
        final candidates = [_keioRecord(), _vPointRecord()];

        final results = await Future.wait([
          firstStore.saveIfUnchanged([candidates[0]], expected: []),
          secondStore.saveIfUnchanged([candidates[1]], expected: []),
        ]);

        expect(results.where((saved) => saved), hasLength(1));
        final winner = candidates[results.indexOf(true)];
        expect((await firstStore.load(refresh: true)).single.id, winner.id);
      },
      skip: !kIsWeb,
    );

    test('tolerates corrupted local storage payload', () async {
      const store = AssetExternalPointsStore.forOwner('owner-a');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(store.storageKey, '{not-valid-json');

      expect(await store.hasSavedSetting(prefs: prefs), isFalse);
      expect(await store.load(prefs: prefs), isEmpty);
      final saved = await store.saveIfUnchanged([_keioRecord()], expected: []);
      expect(saved, isFalse);
      expect(prefs.getString(store.storageKey), '{not-valid-json');
    });
  });

  test('mirror writes cannot replace a newer revision', () async {
    const owner = 'synthetic-owner';
    final submittedAt = DateTime.utc(2026, 6, 20);
    Map<String, dynamic>? stored;
    final client = SupabaseClient(
      'https://example.invalid',
      'test-key',
      accessToken: () async => 'synthetic-token',
      httpClient: MockClient((request) async {
        const headers = {'content-type': 'application/json'};
        expect(request.url.path, '/rest/v1/asset_pref_mirror');
        expect(request.url.queryParameters['select'], 'updated_at');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.method == 'POST') {
          final preferHeader = request.headers['prefer'];
          expect(preferHeader, isNot(contains('merge-duplicates')));
          expect(body['user_id'], owner);
          expect(body['pref_key'], AssetExternalPointsStore.mirrorPrefKey);
          if (stored != null) {
            return http.Response(
              '{"code":"23505","message":"duplicate"}',
              409,
              headers: headers,
              request: request,
            );
          }
        } else {
          expect(request.method, 'PATCH');
          expect(request.url.queryParameters['user_id'], 'eq.$owner');
          expect(
            request.url.queryParameters['pref_key'],
            'eq.${AssetExternalPointsStore.mirrorPrefKey}',
          );
          if (request.url.queryParameters['updated_at'] !=
              'eq.${stored!['updated_at']}') {
            return http.Response('[]', 200, headers: headers, request: request);
          }
        }
        stored = body;
        return http.Response(
          jsonEncode([
            {'updated_at': body['updated_at']},
          ]),
          200,
          headers: headers,
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);

    Future<String> save(
      AssetExternalPointRecord record, {
      String? revision,
    }) =>
        AssetExternalPointsStore.saveMirrorIfUnchanged(
          client,
          owner: owner,
          records: [record],
          revision: revision,
          now: submittedAt,
        );

    final original = _keioRecord();
    final firstRevision = await save(original);
    final duplicateInsert = save(_vPointRecord());
    await expectLater(duplicateInsert, throwsA(isA<PostgrestException>()));

    final updated = _vPointRecord();
    final newRevision = await save(updated, revision: firstRevision);
    final firstUpdatedAt = DateTime.parse(firstRevision);
    expect(DateTime.parse(newRevision).isAfter(firstUpdatedAt), isTrue);

    final staleUpdate = save(original, revision: firstRevision);
    await expectLater(staleUpdate, throwsStateError);
    expect(stored!['updated_at'], newRevision);
    final persisted = AssetExternalPointsStore.decodeMirrorValue(
      stored!['value'],
    );
    expect(persisted.single.id, updated.id);
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
      expect(decodedKeio.balanceAfter, 105);
      expect(decodedKeio.deltaPoints, 25);
      expect(decodedKeio.balanceBefore, 80);
      expect(decodedKeio.expiringPoints, 20);
      expect(decodedKeio.expiresOn?.year, 2027);
      expect(decodedKeio.expiresOn?.month, 4);
      expect(decodedKeio.expiresOn?.day, 29);
      expect(decodedKeio.merchant, 'サンプル書店');
      expect(decodedKeio.pointTargetAmountYen, 840);
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
              'balanceAfter': 105,
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
    test(
        'returns decoded records only when row user_id matches non-empty owner',
        () {
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
