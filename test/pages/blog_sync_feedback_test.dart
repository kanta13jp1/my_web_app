// R21: ブログ同期エラー人間語化の純ロジックテスト。
// 本番実障害 (schedule-hub 502 {"error":"Qiita list: 401"} = QIITA_ACCESS_TOKEN
// 失効) を生 FunctionException のまま表示せず、是正手順つき文言へ変換する
// 回帰を固定する。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/admin/blog_sync_feedback.dart';

void main() {
  group('composeBlogSyncErrorMessage', () {
    test('Qiita 401 はトークン失効+是正手順を名指しする(本番実ペイロード)', () {
      final message = composeBlogSyncErrorMessage(
        status: 502,
        details: {'error': 'Qiita list: 401'},
      );
      expect(message, contains('Qiitaトークンが失効'));
      expect(message, contains('QIITA_ACCESS_TOKEN'));
      expect(message, isNot(contains('FunctionException')));
    });

    test('QIITA_ACCESS_TOKEN 未設定は secrets 設定を案内', () {
      final message = composeBlogSyncErrorMessage(
        status: 500,
        details: {'error': 'QIITA_ACCESS_TOKEN not set'},
      );
      expect(message, contains('QIITA_ACCESS_TOKEN が未設定'));
    });

    test('DEVTO_API_KEY 未設定は secrets 設定を案内', () {
      final message = composeBlogSyncErrorMessage(
        status: 500,
        details: {'error': 'DEVTO_API_KEY not set'},
      );
      expect(message, contains('DEVTO_API_KEY が未設定'));
    });

    test('その他は HTTP status + エラー本文', () {
      final message = composeBlogSyncErrorMessage(
        status: 502,
        details: {'error': 'dev.to 500: oops'},
      );
      expect(message, contains('HTTP 502'));
      expect(message, contains('dev.to 500: oops'));
    });

    test('details が Map でない場合は fallback 文字列で判定する', () {
      final message = composeBlogSyncErrorMessage(
        fallback:
            'FunctionException(status: 502, details: {error: Qiita list: 401},'
            ' reasonPhrase: )',
      );
      expect(message, contains('Qiitaトークンが失効'));
    });

    test('情報ゼロでも文として成立する', () {
      expect(composeBlogSyncErrorMessage(), '同期に失敗しました。');
    });

    test('error キーの無い Map details でも情報を全損させない', () {
      final message = composeBlogSyncErrorMessage(
        status: 500,
        details: {'message': 'unexpected'},
      );
      expect(message, contains('unexpected'));
    });

    test('サーバー同梱 hint (upstream_error.ts) を最優先で表示する', () {
      final message = composeBlogSyncErrorMessage(
        status: 502,
        details: {
          'ok': false,
          'error': 'Qiita API error 401',
          'error_code': 'upstream_auth_error',
          'upstream_status': 401,
          'hint': 'QIITA_ACCESS_TOKEN が失効/権限不足の可能性。再発行して更新してください。',
        },
      );
      expect(message, contains('HTTP 502'));
      expect(message, contains('Qiita API error 401'));
      expect(message, contains('再発行して更新してください'));
    });
  });

  group('composeBlogSyncSuccessLine', () {
    test('Qiita は articles_synced を件数表示', () {
      expect(
        composeBlogSyncSuccessLine('Qiita', {
          'success': true,
          'articles_synced': 12,
        }),
        'Qiita: 12件同期',
      );
    });

    test('dev.to は synced を件数表示', () {
      expect(
        composeBlogSyncSuccessLine('dev.to', {'success': true, 'synced': 7}),
        'dev.to: 7件同期',
      );
    });

    test('件数が読めない場合は同期完了に留める', () {
      expect(
        composeBlogSyncSuccessLine('Qiita', {'success': true}),
        'Qiita: 同期完了',
      );
      expect(composeBlogSyncSuccessLine('Qiita', null), 'Qiita: 同期完了');
    });
  });

  group('blogEngagementFreshnessLabel', () {
    final now = DateTime.utc(2026, 7, 12, 11, 0);

    test('最新 updated_at から鮮度を出す(全行走査で max)', () {
      final rows = [
        {'updated_at': '2026-07-10T10:00:00Z'},
        {'updated_at': '2026-07-12T09:30:00Z'},
        {'updated_at': '2026-07-11T10:00:00Z'},
      ];
      expect(blogEngagementFreshnessLabel(rows, now), '最終同期: 1時間前');
    });

    test('1日以上前は日数表示(凍結値を今に見せない)', () {
      final rows = [
        {'updated_at': '2026-07-09T10:00:00Z'},
      ];
      expect(blogEngagementFreshnessLabel(rows, now), '最終同期: 3日前');
    });

    test('updated_at が読めない場合は null', () {
      expect(blogEngagementFreshnessLabel([], now), isNull);
      final badRows = [
        {'updated_at': 'bad'},
      ];
      expect(blogEngagementFreshnessLabel(badRows, now), isNull);
    });
  });

  group('blogEngagementFreshnessByPlatform', () {
    final now = DateTime.utc(2026, 7, 12, 11, 0);

    test('複数 platform は個別表示(Qiita凍結が dev.to の新鮮さに隠れない)', () {
      final rows = [
        {'platform': 'qiita', 'updated_at': '2026-07-09T10:00:00Z'},
        {'platform': 'devto', 'updated_at': '2026-07-12T10:30:00Z'},
      ];
      expect(
        blogEngagementFreshnessByPlatform(rows, now),
        '最終同期 — Qiita: 3日前 / dev.to: 1時間以内',
      );
    });

    test('単一 platform は従来形式', () {
      final rows = [
        {'platform': 'qiita', 'updated_at': '2026-07-12T09:30:00Z'},
      ];
      expect(
        blogEngagementFreshnessByPlatform(rows, now),
        '最終同期: 1時間前',
      );
    });

    test('platform 列が無ければ全体ラベルへフォールバック', () {
      final rows = [
        {'updated_at': '2026-07-11T10:00:00Z'},
      ];
      expect(
        blogEngagementFreshnessByPlatform(rows, now),
        '最終同期: 1日前',
      );
    });
  });
}
