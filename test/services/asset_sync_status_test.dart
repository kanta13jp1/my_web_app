import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_sync_status.dart';

void main() {
  group('AssetSyncStatusSummary', () {
    test('logged out → loggedOut level regardless of sources', () {
      const summary = AssetSyncStatusSummary(
        loggedIn: false,
        sources: <AssetSyncDomain, AssetSyncSource>{
          AssetSyncDomain.watchlist: AssetSyncSource.localOnly,
          AssetSyncDomain.mainAccount: AssetSyncSource.synced,
        },
      );
      expect(summary.level, AssetSyncLevel.loggedOut);
      expect(summary.headline, '未ログイン：この端末にのみ保存');
    });

    test('logged in, all synced → allSynced level', () {
      final summary = AssetSyncStatusSummary(
        loggedIn: true,
        sources: <AssetSyncDomain, AssetSyncSource>{
          for (final domain in AssetSyncDomain.values)
            domain: AssetSyncSource.empty,
          AssetSyncDomain.watchlist: AssetSyncSource.synced,
          AssetSyncDomain.mainAccount: AssetSyncSource.synced,
          AssetSyncDomain.revolving: AssetSyncSource.empty,
        },
      );
      expect(summary.level, AssetSyncLevel.allSynced);
      expect(summary.headline, 'サーバ同期済み');
      expect(summary.localOnlyCount, 0);
    });

    test('logged in with some local-only → partialLocal + count + list', () {
      const summary = AssetSyncStatusSummary(
        loggedIn: true,
        sources: <AssetSyncDomain, AssetSyncSource>{
          AssetSyncDomain.mainAccount: AssetSyncSource.synced,
          AssetSyncDomain.watchlist: AssetSyncSource.localOnly,
          AssetSyncDomain.revolving: AssetSyncSource.localOnly,
          AssetSyncDomain.inflow: AssetSyncSource.empty,
        },
      );
      expect(summary.level, AssetSyncLevel.partialLocal);
      expect(summary.localOnlyCount, 2);
      expect(summary.headline, '未同期 2 項目');
      // enum 宣言順で安定 (watchlist が revolving より先)。
      expect(summary.localOnlyDomains, <AssetSyncDomain>[
        AssetSyncDomain.watchlist,
        AssetSyncDomain.revolving,
      ]);
      expect(summary.isLocalOnly(AssetSyncDomain.watchlist), isTrue);
      expect(summary.isLocalOnly(AssetSyncDomain.mainAccount), isFalse);
    });

    test('verified empty domains have noData rather than green saved', () {
      final summary = AssetSyncStatusSummary(
        loggedIn: true,
        sources: <AssetSyncDomain, AssetSyncSource>{
          for (final domain in AssetSyncDomain.values)
            domain: AssetSyncSource.empty,
        },
      );
      expect(summary.hasAnyData, isFalse);
      expect(summary.level, AssetSyncLevel.noData);
    });

    test('initial or missing domains remain unverified', () {
      const summary = AssetSyncStatusSummary(
        loggedIn: true,
        sources: <AssetSyncDomain, AssetSyncSource>{},
      );
      expect(summary.level, AssetSyncLevel.unverified);
      expect(summary.unverifiedDomains, AssetSyncDomain.values);
      expect(summary.hasAnyData, isFalse);
    });

    test('a verified domain does not hide unverified domains', () {
      const summary = AssetSyncStatusSummary(
        loggedIn: true,
        sources: <AssetSyncDomain, AssetSyncSource>{
          AssetSyncDomain.watchlist: AssetSyncSource.synced,
          AssetSyncDomain.monthlyState: AssetSyncSource.unverified,
        },
      );
      expect(summary.level, AssetSyncLevel.unverified);
      expect(summary.hasAnyData, isTrue);
      expect(summary.localOnlyCount, 0);
    });

    test('domain labels are stable Japanese strings', () {
      expect(AssetSyncDomain.mainAccount.label, 'メイン口座');
      expect(AssetSyncDomain.monthlyState.label, '月次の支払・計画設定');
    });
  });
}
