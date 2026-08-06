// R21: AI クォータ監視の純ロジックテスト。
// 未計測(行なし)/計測停止(古い checked_at)を「正常」と捏造しない誠実性規律
// (R17/R19) の回帰を固定する。
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/pages/admin/quota_dashboard_signals.dart';

void main() {
  final now = DateTime(2026, 7, 12, 11, 0);

  group('resolveQuotaToolStatus', () {
    test('行なしは unmeasured(正常と捏造しない)', () {
      expect(
        resolveQuotaToolStatus(
          hasRow: false,
          alert: false,
          checkedAt: null,
          now: now,
        ),
        QuotaToolStatus.unmeasured,
      );
    });

    test('alert フラグは鮮度より優先して alert', () {
      expect(
        resolveQuotaToolStatus(
          hasRow: true,
          alert: true,
          checkedAt: '2026-07-01',
          now: now,
        ),
        QuotaToolStatus.alert,
      );
    });

    test('前日計測(日次 cron 正常範囲)は ok', () {
      expect(
        resolveQuotaToolStatus(
          hasRow: true,
          alert: false,
          checkedAt: '2026-07-11',
          now: now,
        ),
        QuotaToolStatus.ok,
      );
    });

    test('2日以上前の計測は stale(計測停止を正常に見せない)', () {
      expect(
        resolveQuotaToolStatus(
          hasRow: true,
          alert: false,
          checkedAt: '2026-07-09',
          now: now,
        ),
        QuotaToolStatus.stale,
      );
    });

    test('checked_at パース不能は stale(不明を健全に見せない)', () {
      expect(
        resolveQuotaToolStatus(
          hasRow: true,
          alert: false,
          checkedAt: 'not-a-date',
          now: now,
        ),
        QuotaToolStatus.stale,
      );
    });
  });

  group('quotaStatusBadgeLabel', () {
    test('4状態のラベル', () {
      expect(quotaStatusBadgeLabel(QuotaToolStatus.unmeasured), '未計測');
      expect(quotaStatusBadgeLabel(QuotaToolStatus.alert), 'アラート');
      expect(quotaStatusBadgeLabel(QuotaToolStatus.stale), '計測停止?');
      expect(quotaStatusBadgeLabel(QuotaToolStatus.ok), '正常');
    });
  });

  group('quotaCostUsd', () {
    test('cost_usd を読む', () {
      expect(quotaCostUsd({'cost_usd': 1.25}), 1.25);
    });

    test('cost_usd_est へフォールバック(openai step の書式)', () {
      expect(quotaCostUsd({'cost_usd_est': 0.5}), 0.5);
    });

    test('どちらも無い場合は null(\$0.00 を捏造しない)', () {
      expect(quotaCostUsd({'plan': 'copilot_pro'}), isNull);
      expect(quotaCostUsd({}), isNull);
    });

    test('測定済み \$0 は 0.0 として返す(未取得と区別)', () {
      expect(quotaCostUsd({'cost_usd': 0}), 0.0);
    });
  });

  group('quotaCheckedAgeDays', () {
    test('経過日数を返す', () {
      expect(quotaCheckedAgeDays('2026-07-09', now), 3);
      expect(quotaCheckedAgeDays('2026-07-12', now), 0);
    });

    test('パース不能/null は null', () {
      expect(quotaCheckedAgeDays('bad', now), isNull);
      expect(quotaCheckedAgeDays(null, now), isNull);
    });
  });
}
