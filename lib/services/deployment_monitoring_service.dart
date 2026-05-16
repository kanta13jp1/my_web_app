class DeploymentMonitoringRequest {
  const DeploymentMonitoringRequest({
    required this.serviceName,
    required this.platform,
    required this.environment,
    required this.provider,
    this.autoMonitoringEnabled = true,
    this.thresholdOverrides = const <String, double>{},
    this.createdAt,
  });

  final String serviceName;
  final String platform;
  final String environment;
  final String provider;
  final bool autoMonitoringEnabled;
  final Map<String, double> thresholdOverrides;
  final DateTime? createdAt;
}

class MonitoringMetricTemplate {
  const MonitoringMetricTemplate({
    required this.key,
    required this.label,
    required this.unit,
    required this.warningThreshold,
    required this.criticalThreshold,
    required this.sampleValue,
    required this.description,
  });

  final String key;
  final String label;
  final String unit;
  final double warningThreshold;
  final double criticalThreshold;
  final double sampleValue;
  final String description;

  MonitoringMetricTemplate copyWith({
    double? warningThreshold,
    double? criticalThreshold,
  }) {
    return MonitoringMetricTemplate(
      key: key,
      label: label,
      unit: unit,
      warningThreshold: warningThreshold ?? this.warningThreshold,
      criticalThreshold: criticalThreshold ?? this.criticalThreshold,
      sampleValue: sampleValue,
      description: description,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'unit': unit,
      'warning_threshold': warningThreshold,
      'critical_threshold': criticalThreshold,
      'sample_value': sampleValue,
      'description': description,
    };
  }
}

class DeploymentMonitoringSetup {
  const DeploymentMonitoringSetup({
    required this.id,
    required this.serviceName,
    required this.platform,
    required this.environment,
    required this.provider,
    required this.autoMonitoringEnabled,
    required this.metrics,
    required this.dashboardWidgets,
    required this.setupSteps,
    required this.createdAt,
    required this.statusLabel,
  });

  final String id;
  final String serviceName;
  final String platform;
  final String environment;
  final String provider;
  final bool autoMonitoringEnabled;
  final List<MonitoringMetricTemplate> metrics;
  final List<String> dashboardWidgets;
  final List<String> setupSteps;
  final DateTime createdAt;
  final String statusLabel;

  int get metricCount => metrics.length;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_name': serviceName,
      'platform': platform,
      'environment': environment,
      'provider': provider,
      'auto_monitoring_enabled': autoMonitoringEnabled,
      'metrics': metrics.map((metric) => metric.toJson()).toList(),
      'dashboard_widgets': dashboardWidgets,
      'setup_steps': setupSteps,
      'created_at': createdAt.toUtc().toIso8601String(),
      'status_label': statusLabel,
    };
  }
}

class DeploymentMonitoringService {
  const DeploymentMonitoringService();

  static const supportedPlatforms = <String>[
    'Supabase Edge Function',
    'Vercel Web App',
    'AWS ECS / Lambda',
    'Generic API Service',
  ];

  static const supportedProviders = <String>[
    'Built-in dashboard',
    'CloudWatch',
    'Datadog',
  ];

  DeploymentMonitoringSetup buildSetup(DeploymentMonitoringRequest request) {
    final createdAt = (request.createdAt ?? DateTime.now()).toUtc();
    final serviceName = _normalizeServiceName(request.serviceName);
    final id = '${_slug(serviceName)}-${createdAt.millisecondsSinceEpoch}';

    if (!request.autoMonitoringEnabled) {
      return DeploymentMonitoringSetup(
        id: id,
        serviceName: serviceName,
        platform: request.platform,
        environment: request.environment,
        provider: request.provider,
        autoMonitoringEnabled: false,
        metrics: const <MonitoringMetricTemplate>[],
        dashboardWidgets: const <String>[
          'Opt-out audit trail',
          'Manual monitoring reminder',
        ],
        setupSteps: const <String>[
          'Record opt-out reason before production release',
          'Create a WBS follow-up if the service becomes customer-facing',
        ],
        createdAt: createdAt,
        statusLabel: 'Monitoring opt-out',
      );
    }

    final metrics = defaultMetricsFor(request.platform).map((metric) {
      final override = request.thresholdOverrides[metric.key];
      if (override == null) return metric;
      return metric.copyWith(
        warningThreshold: override,
        criticalThreshold: override * 1.25,
      );
    }).toList(growable: false);

    return DeploymentMonitoringSetup(
      id: id,
      serviceName: serviceName,
      platform: request.platform,
      environment: request.environment,
      provider: request.provider,
      autoMonitoringEnabled: true,
      metrics: metrics,
      dashboardWidgets: _dashboardWidgetsFor(request.platform),
      setupSteps: _setupStepsFor(request.provider, request.platform),
      createdAt: createdAt,
      statusLabel: 'Monitoring auto-enabled',
    );
  }

  List<MonitoringMetricTemplate> defaultMetricsFor(String platform) {
    final normalized = platform.toLowerCase();
    final metrics = <MonitoringMetricTemplate>[
      const MonitoringMetricTemplate(
        key: 'availability',
        label: 'Availability',
        unit: '%',
        warningThreshold: 99,
        criticalThreshold: 95,
        sampleValue: 99.9,
        description: 'Successful health checks over the last 24 hours.',
      ),
      const MonitoringMetricTemplate(
        key: 'error_rate',
        label: 'Error rate',
        unit: '%',
        warningThreshold: 1,
        criticalThreshold: 5,
        sampleValue: 0.2,
        description: 'HTTP 5xx or failed job ratio over the last hour.',
      ),
      const MonitoringMetricTemplate(
        key: 'p95_latency',
        label: 'p95 latency',
        unit: 'ms',
        warningThreshold: 800,
        criticalThreshold: 1500,
        sampleValue: 240,
        description: '95th percentile response time.',
      ),
      const MonitoringMetricTemplate(
        key: 'cpu_or_invocations',
        label: 'CPU / invocations',
        unit: 'score',
        warningThreshold: 75,
        criticalThreshold: 90,
        sampleValue: 38,
        description: 'CPU pressure or function invocation saturation.',
      ),
    ];
    if (normalized.contains('edge') || normalized.contains('lambda')) {
      metrics.add(
        const MonitoringMetricTemplate(
          key: 'cold_start',
          label: 'Cold start',
          unit: 'ms',
          warningThreshold: 1200,
          criticalThreshold: 2500,
          sampleValue: 410,
          description: 'Serverless cold start duration.',
        ),
      );
    }
    if (normalized.contains('ecs') || normalized.contains('generic')) {
      metrics.add(
        const MonitoringMetricTemplate(
          key: 'memory_pressure',
          label: 'Memory pressure',
          unit: '%',
          warningThreshold: 80,
          criticalThreshold: 92,
          sampleValue: 47,
          description: 'Resident memory or container memory pressure.',
        ),
      );
    }
    return metrics;
  }

  List<String> _dashboardWidgetsFor(String platform) {
    final widgets = <String>[
      'Health summary',
      'Latency and error trend',
      'Recent incidents',
      'Alert threshold table',
    ];
    if (platform.toLowerCase().contains('edge')) {
      widgets.add('Function invocation heatmap');
    }
    return widgets;
  }

  List<String> _setupStepsFor(String provider, String platform) {
    final steps = <String>[
      'Create default health check target',
      'Attach metric thresholds to the service record',
      'Show metrics on the deployment monitoring dashboard',
    ];
    if (provider == 'CloudWatch') {
      steps.add('Prepare CloudWatch alarm mapping for AWS resources');
    } else if (provider == 'Datadog') {
      steps.add('Prepare Datadog monitor payload for external sync');
    } else {
      steps.add('Keep metrics in the built-in dashboard until external sync');
    }
    if (platform.toLowerCase().contains('vercel')) {
      steps.add('Track deployment URL and production alias health');
    }
    return steps;
  }

  String _normalizeServiceName(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'new-service' : trimmed;
  }

  String _slug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'new-service' : slug;
  }
}
