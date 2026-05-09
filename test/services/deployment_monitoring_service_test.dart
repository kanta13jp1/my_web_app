import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_app/services/deployment_monitoring_service.dart';

void main() {
  group('DeploymentMonitoringService', () {
    const service = DeploymentMonitoringService();

    test('enables default monitoring for a new service deployment', () {
      final setup = service.buildSetup(
        DeploymentMonitoringRequest(
          serviceName: 'Checkout API',
          platform: 'Supabase Edge Function',
          environment: 'production',
          provider: 'Built-in dashboard',
          createdAt: DateTime.utc(2026, 5, 5, 12),
        ),
      );

      expect(setup.autoMonitoringEnabled, isTrue);
      expect(setup.serviceName, 'Checkout API');
      expect(setup.metrics.map((metric) => metric.key), contains('error_rate'));
      expect(setup.metrics.map((metric) => metric.key), contains('cold_start'));
      expect(setup.dashboardWidgets, contains('Health summary'));
      expect(setup.statusLabel, 'Monitoring auto-enabled');
    });

    test('keeps an explicit opt-out auditable', () {
      final setup = service.buildSetup(
        DeploymentMonitoringRequest(
          serviceName: 'Internal spike',
          platform: 'Generic API Service',
          environment: 'development',
          provider: 'Datadog',
          autoMonitoringEnabled: false,
          createdAt: DateTime.utc(2026, 5, 5, 12),
        ),
      );

      expect(setup.autoMonitoringEnabled, isFalse);
      expect(setup.metrics, isEmpty);
      expect(setup.dashboardWidgets, contains('Opt-out audit trail'));
      expect(setup.setupSteps.join('\n'), contains('WBS follow-up'));
    });

    test('applies custom warning thresholds and keeps dashboard visible', () {
      final setup = service.buildSetup(
        DeploymentMonitoringRequest(
          serviceName: '',
          platform: 'AWS ECS / Lambda',
          environment: 'staging',
          provider: 'CloudWatch',
          thresholdOverrides: const {'p95_latency': 500},
          createdAt: DateTime.utc(2026, 5, 5, 12),
        ),
      );

      final latency = setup.metrics.singleWhere(
        (metric) => metric.key == 'p95_latency',
      );
      expect(setup.serviceName, 'new-service');
      expect(latency.warningThreshold, 500);
      expect(latency.criticalThreshold, 625);
      expect(setup.metrics.map((metric) => metric.key), contains('cold_start'));
      expect(setup.setupSteps.join('\n'), contains('CloudWatch'));
    });
  });
}
