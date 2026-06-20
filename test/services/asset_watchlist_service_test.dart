import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_watchlist_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AssetWatchlistService', () {
    const service = AssetWatchlistService();

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('saves, loads and replaceAll clears entries', () async {
      await service.saveEntry(
        AssetWatchlistEntry(
          assetType: 'gold',
          group: 'invest',
          memo: 'hedge',
          addedAt: DateTime.utc(2026, 6, 14),
        ),
      );
      final loaded = await service.loadEntries();
      expect(loaded.map((e) => e.assetType), <String>['gold']);

      await service.replaceAll(const <AssetWatchlistEntry>[]);
      expect(await service.loadEntries(), isEmpty);
    });

    test('encode/decode mirror value round-trips (端末A→端末B 同期)', () {
      final entries = <AssetWatchlistEntry>[
        AssetWatchlistEntry(
          assetType: 'gold',
          group: 'invest',
          memo: 'hedge',
          addedAt: DateTime.utc(2026, 6, 14),
        ),
        AssetWatchlistEntry(
          assetType: 'btc',
          group: '',
          memo: '',
          addedAt: DateTime.utc(2026, 1, 1),
        ),
      ];

      final encoded = AssetWatchlistService.encodeMirrorValue(entries);
      final decoded = AssetWatchlistService.decodeMirrorValue(encoded);

      expect(
        decoded.map((e) => e.assetType),
        unorderedEquals(<String>['gold', 'btc']),
      );
      final gold = decoded.firstWhere((e) => e.assetType == 'gold');
      expect(gold.group, 'invest');
      expect(gold.memo, 'hedge');
    });

    test('decodeMirrorValue ignores malformed input and empty assetType', () {
      expect(AssetWatchlistService.decodeMirrorValue(null), isEmpty);
      expect(AssetWatchlistService.decodeMirrorValue('not a map'), isEmpty);

      final decoded = AssetWatchlistService.decodeMirrorValue(
        <String, dynamic>{
          'entries': <dynamic>[
            <String, dynamic>{
              'assetType': 'gold',
              'group': 'invest',
              'memo': '',
              'addedAt': '',
            },
            'broken',
            <String, dynamic>{
              'assetType': '',
              'group': 'x',
              'memo': '',
              'addedAt': '',
            },
          ],
        },
      );
      expect(decoded.map((e) => e.assetType), <String>['gold']);
    });
  });
}
