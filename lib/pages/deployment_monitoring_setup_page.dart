import 'package:flutter/material.dart';
import 'package:my_web_app/models/micro_survey.dart';
import 'package:my_web_app/services/deployment_monitoring_service.dart';
import 'package:my_web_app/services/micro_survey_repository.dart';
import 'package:my_web_app/widgets/micro_survey_bottom_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeploymentMonitoringSetupPage extends StatefulWidget {
  const DeploymentMonitoringSetupPage({super.key});

  @override
  State<DeploymentMonitoringSetupPage> createState() =>
      _DeploymentMonitoringSetupPageState();
}

class _DeploymentMonitoringSetupPageState
    extends State<DeploymentMonitoringSetupPage> {
  final _service = const DeploymentMonitoringService();
  final _nameController = TextEditingController(text: 'customer-api');
  final _supabase = Supabase.instance.client;

  String _platform = DeploymentMonitoringService.supportedPlatforms.first;
  String _provider = DeploymentMonitoringService.supportedProviders.first;
  String _environment = 'production';
  bool _autoMonitoringEnabled = true;
  bool _saving = false;
  String? _saveMessage;
  DeploymentMonitoringSetup? _setup;

  @override
  void initState() {
    super.initState();
    _buildPreview();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _buildPreview() {
    setState(() {
      _saveMessage = null;
      _setup = _service.buildSetup(
        DeploymentMonitoringRequest(
          serviceName: _nameController.text,
          platform: _platform,
          environment: _environment,
          provider: _provider,
          autoMonitoringEnabled: _autoMonitoringEnabled,
        ),
      );
    });
  }

  Future<void> _createSetup() async {
    final setup = _setup;
    if (setup == null) return;
    setState(() {
      _saving = true;
      _saveMessage = null;
    });
    try {
      if (_supabase.auth.currentUser != null) {
        final response = await _supabase.functions.invoke(
          'enterprise-hub',
          body: {
            'action': 'deployment.monitoring.setup',
            ...setup.toJson(),
          },
        );
        final data = response.data;
        final ok =
            response.status == 200 && data is Map && data['success'] == true;
        if (!ok) {
          throw Exception(data is Map ? data['error'] : 'save failed');
        }
      }
      if (!mounted) return;
      setState(() {
        _saveMessage =
            setup.autoMonitoringEnabled ? 'モニタリング設定を作成しました' : 'オプトアウトを記録しました';
      });
      await presentMicroSurveyIfEligible(
        context: context,
        repository: SupabaseMicroSurveyRepository(_supabase),
        surveyContext: const MicroSurveyContext(
          trigger: MicroSurveyTrigger.deploymentMonitoringCreated,
          route: '/deployment-monitoring',
          resourceType: 'deployment_monitoring_setup',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saveMessage = '保存は未完了です: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    return Scaffold(
      appBar: AppBar(
        title: const Text('デプロイ監視自動セットアップ'),
        actions: [
          IconButton(
            tooltip: 'プレビュー更新',
            onPressed: _buildPreview,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final form = _buildForm();
          final dashboard =
              setup == null ? const SizedBox.shrink() : _buildDashboard(setup);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: form),
                      const SizedBox(width: 16),
                      Expanded(child: dashboard),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      form,
                      const SizedBox(height: 16),
                      dashboard,
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '新規サービス',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'サービス名',
                prefixIcon: Icon(Icons.rocket_launch_outlined),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _buildPreview(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _platform,
              decoration: const InputDecoration(
                labelText: 'デプロイ先',
                border: OutlineInputBorder(),
              ),
              items: DeploymentMonitoringService.supportedPlatforms
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _platform = value);
                _buildPreview();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _environment,
              decoration: const InputDecoration(
                labelText: '環境',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'production',
                  child: Text('production'),
                ),
                DropdownMenuItem(value: 'staging', child: Text('staging')),
                DropdownMenuItem(
                  value: 'development',
                  child: Text('development'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _environment = value);
                _buildPreview();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _provider,
              decoration: const InputDecoration(
                labelText: '監視プロバイダー',
                border: OutlineInputBorder(),
              ),
              items: DeploymentMonitoringService.supportedProviders
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _provider = value);
                _buildPreview();
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _autoMonitoringEnabled,
              title: const Text('基本監視を自動で有効化'),
              subtitle: const Text('オフにするとオプトアウトとして記録します'),
              contentPadding: EdgeInsets.zero,
              onChanged: (value) {
                setState(() => _autoMonitoringEnabled = value);
                _buildPreview();
              },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _createSetup,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_chart_outlined),
              label: const Text('作成'),
            ),
            if (_saveMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _saveMessage!,
                style: TextStyle(
                  color: _saveMessage!.startsWith('保存は')
                      ? Colors.red
                      : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(DeploymentMonitoringSetup setup) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  setup.autoMonitoringEnabled
                      ? Icons.monitor_heart_outlined
                      : Icons.visibility_off_outlined,
                  color: setup.autoMonitoringEnabled
                      ? const Color(0xFF0F766E)
                      : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        setup.serviceName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text('${setup.platform} / ${setup.environment}'),
                    ],
                  ),
                ),
                Chip(label: Text(setup.statusLabel)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (setup.metrics.isEmpty)
          _buildOptOutPanel(setup)
        else
          _buildMetricsGrid(setup.metrics),
        const SizedBox(height: 12),
        _buildListPanel(
          title: 'ダッシュボードに追加される項目',
          icon: Icons.dashboard_customize_outlined,
          items: setup.dashboardWidgets,
        ),
        const SizedBox(height: 12),
        _buildListPanel(
          title: '自動セットアップ手順',
          icon: Icons.playlist_add_check_outlined,
          items: setup.setupSteps,
        ),
      ],
    );
  }

  Widget _buildOptOutPanel(DeploymentMonitoringSetup setup) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '監視は無効です',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${setup.serviceName} は自動監視を使わない設定です。'
              '本番公開前に手動監視またはWBSフォローアップを追加してください。',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(List<MonitoringMetricTemplate> metrics) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 150,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${metric.sampleValue}${metric.unit}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Warn ${metric.warningThreshold}${metric.unit} / '
                  'Critical ${metric.criticalThreshold}${metric.unit}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  metric.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildListPanel({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
