import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/asset_management_ai_summary_refresh.dart';

void main() {
  group('AssetManagementAiSummaryRefresh.isStale', () {
    test('is stale when there is no result yet (needs first generation)', () {
      expect(
        AssetManagementAiSummaryRefresh.isStale(
          currentKey: 'sha256:abc',
          resultKey: null,
          hasResult: false,
        ),
        isTrue,
      );
    });

    test('is fresh when the result was generated for the current key', () {
      expect(
        AssetManagementAiSummaryRefresh.isStale(
          currentKey: 'sha256:abc',
          resultKey: 'sha256:abc',
          hasResult: true,
        ),
        isFalse,
      );
    });

    test(
      'is stale when data changed (current key differs from result key)',
      () {
        // 支払済みチェックを入れるとフィンガープリントが変わる。旧バグでは
        // ここで再生成が走らず古い「未払い」サマリーが残り続けた。
        expect(
          AssetManagementAiSummaryRefresh.isStale(
            currentKey: 'sha256:paid',
            resultKey: 'sha256:unpaid',
            hasResult: true,
          ),
          isTrue,
        );
      },
    );

    test('is stale when a result key is unexpectedly missing', () {
      expect(
        AssetManagementAiSummaryRefresh.isStale(
          currentKey: 'sha256:abc',
          resultKey: null,
          hasResult: true,
        ),
        isTrue,
      );
    });
  });

  group('AssetManagementAiSummaryRefresh.canReusePersisted', () {
    test('reuses only an exact financial-data fingerprint', () {
      expect(
        AssetManagementAiSummaryRefresh.canReusePersisted(
          currentKey: 'sha256:current',
          cachedKey: 'sha256:current',
        ),
        isTrue,
      );
      expect(
        AssetManagementAiSummaryRefresh.canReusePersisted(
          currentKey: 'sha256:paid-and-updated-rate',
          cachedKey: 'sha256:unpaid-and-old-rate',
        ),
        isFalse,
      );
    });
  });
  group('AssetManagementAiSummaryRefresh.shouldThrottleFailedRetry', () {
    const cooldown = Duration(minutes: 60);

    test('does not throttle when there is no recorded attempt', () {
      // 初回 (試行履歴なし) は必ず生成する。
      expect(
        AssetManagementAiSummaryRefresh.shouldThrottleFailedRetry(
          force: false,
          sinceLastAttempt: null,
          cooldown: cooldown,
        ),
        isFalse,
      );
    });

    test('throttles a fresh retry within the cooldown window', () {
      // 直近の試行 (500 で失敗し保存されなかった) から 5 分。再試行を抑える。
      expect(
        AssetManagementAiSummaryRefresh.shouldThrottleFailedRetry(
          force: false,
          sinceLastAttempt: const Duration(minutes: 5),
          cooldown: cooldown,
        ),
        isTrue,
      );
    });

    test('allows retry once the cooldown has elapsed', () {
      expect(
        AssetManagementAiSummaryRefresh.shouldThrottleFailedRetry(
          force: false,
          sinceLastAttempt: const Duration(minutes: 61),
          cooldown: cooldown,
        ),
        isFalse,
      );
    });

    test('never throttles a forced (manual) refresh', () {
      expect(
        AssetManagementAiSummaryRefresh.shouldThrottleFailedRetry(
          force: true,
          sinceLastAttempt: const Duration(minutes: 1),
          cooldown: cooldown,
        ),
        isFalse,
      );
    });
  });
}
