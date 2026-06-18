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
}
