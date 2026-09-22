import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/models/asset_alert.dart';
import 'package:my_web_app/models/asset_anomaly_detection.dart';

void main() {
  test('maps persisted high anomaly to a detailed critical alert', () {
    final detection = AssetAnomalyDetection.fromMap({
      'id': 'detection-1',
      'target_month': '2026-06-01',
      'category': 'food',
      'expected': '30000.00',
      'actual': 60000,
      'delta': '30000',
      'severity': 'high',
      'ai_explanation': '先月より外食が増えています。',
      'detected_at': '2026-07-21T03:00:00Z',
    });

    final alert = detection.toAlert();

    expect(alert.id, 'anomaly_detection:detection-1');
    expect(alert.category, AssetAlertCategory.anomaly);
    expect(alert.severity, AssetAlertSeverity.critical);
    expect(alert.title, '食費の支出に異常を検出');
    expect(alert.detail, contains('期待値 ¥30,000'));
    expect(alert.detail, contains('実績 ¥60,000'));
    expect(alert.detail, contains('差分 +100.0%'));
    expect(alert.detail, contains('先月より外食が増えています。'));
    expect(alert.occurredAt, DateTime.parse('2026-07-21T03:00:00Z'));
  });

  test('maps negative delta and rejects unknown severity', () {
    final detection = AssetAnomalyDetection.fromMap({
      'id': 'detection-2',
      'target_month': '2026-06-01',
      'category': 'custom',
      'expected': 200,
      'actual': 100,
      'delta': -100,
      'severity': 'low',
      'detected_at': '2026-07-21T03:00:00Z',
    });

    expect(detection.toAlert().detail, contains('差分 -50.0%'));
    expect(
      () => AssetAnomalyDetection.fromMap({
        'id': 'bad',
        'target_month': '2026-06-01',
        'category': 'food',
        'expected': 1,
        'actual': 2,
        'delta': 1,
        'severity': 'urgent',
        'detected_at': '2026-07-21T03:00:00Z',
      }),
      throwsFormatException,
    );
  });

  test('round-trips the anomaly alert id', () {
    const alertId = 'anomaly_detection:abc-123';

    expect(AssetAnomalyDetection.isAnomalyAlertId(alertId), isTrue);
    expect(
      AssetAnomalyDetection.detectionIdFromAlertId(alertId),
      'abc-123',
    );
    expect(
      () => AssetAnomalyDetection.detectionIdFromAlertId('local:abc-123'),
      throwsFormatException,
    );
  });
}
