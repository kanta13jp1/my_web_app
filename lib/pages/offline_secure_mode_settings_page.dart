import 'package:flutter/material.dart';

import '../services/offline_secure_mode_settings_service.dart';

class OfflineSecureModeSettingsPage extends StatefulWidget {
  final OfflineSecureModeSettingsService settingsService;
  final OfflineSecureModeAuditGateway auditGateway;

  const OfflineSecureModeSettingsPage({
    super.key,
    this.settingsService = const OfflineSecureModeSettingsService(),
    this.auditGateway = const SupabaseOfflineSecureModeAuditGateway(),
  });

  @override
  State<OfflineSecureModeSettingsPage> createState() =>
      _OfflineSecureModeSettingsPageState();
}

class _OfflineSecureModeSettingsPageState
    extends State<OfflineSecureModeSettingsPage> {
  final TextEditingController _modelPathController = TextEditingController();
  final TextEditingController _vectorDbPathController = TextEditingController();
  final TextEditingController _runtimeUrlController = TextEditingController();

  OfflineSecureModeSettings _settings = const OfflineSecureModeSettings();
  List<OfflineSecureModeAuditEntry> _auditEntries =
      const <OfflineSecureModeAuditEntry>[];
  bool _loading = true;
  bool _saving = false;
  bool _loadingAudit = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _modelPathController.dispose();
    _vectorDbPathController.dispose();
    _runtimeUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
    });
    final settings = await widget.settingsService.loadSettings();
    if (!mounted) return;
    _modelPathController.text = settings.localModelPath;
    _vectorDbPathController.text = settings.localVectorDbPath;
    _runtimeUrlController.text = settings.localRuntimeUrl;
    setState(() {
      _settings = settings;
      _loading = false;
    });
    await _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    if (!mounted) return;
    setState(() {
      _loadingAudit = true;
    });
    final entries = await widget.auditGateway.listRecent(limit: 10);
    if (!mounted) return;
    setState(() {
      _auditEntries = entries;
      _loadingAudit = false;
    });
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    setState(() {
      _saving = true;
    });
    final next = _settings.copyWith(
      localModelPath: _modelPathController.text,
      localVectorDbPath: _vectorDbPathController.text,
      localRuntimeUrl: _runtimeUrlController.text,
    );
    final saved = await widget.settingsService.saveSettings(next);
    if (!mounted) return;
    await widget.auditGateway.recordPolicyEvent(
      settings: saved,
      auditAction: 'settings.update',
      status:
          saved.externalApiBlocked ? 'external_api_blocked' : 'online_allowed',
    );
    if (!mounted) return;
    setState(() {
      _settings = saved;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('オフラインセキュアモード設定を保存しました')),
    );
    await _loadAuditLogs();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outlineVariant;

    return Scaffold(
      appBar: AppBar(
        title: const Text('オフラインセキュアモード'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            onPressed: _loading || _saving ? null : _loadSettings,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatusPanel(settings: _settings),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        key: const ValueKey<String>(
                          'offline_secure_mode_switch',
                        ),
                        secondary: const Icon(Icons.security_outlined),
                        title: const Text('オフラインセキュアモード'),
                        subtitle: Text(
                          _settings.enabled
                              ? '外部API遮断ポリシーを適用します'
                              : 'オンラインLLM呼び出しを許可します',
                        ),
                        value: _settings.enabled,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(enabled: value);
                          });
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        key: const ValueKey<String>(
                          'offline_block_external_api_switch',
                        ),
                        secondary: const Icon(Icons.public_off_outlined),
                        title: const Text('外部API遮断'),
                        subtitle: const Text('ON時はオンラインプロバイダーを遮断対象にします'),
                        value: _settings.blockExternalApiWhenEnabled,
                        onChanged: (value) {
                          setState(() {
                            _settings = _settings.copyWith(
                              blockExternalApiWhenEnabled: value,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  key: ValueKey<int>(_settings.memoryLimitMb),
                  initialValue: _settings.memoryLimitMb,
                  decoration: const InputDecoration(
                    labelText: 'メモリ上限ガード (8GB RAM制約)',
                    border: OutlineInputBorder(),
                  ),
                  items: (<int>{
                    ...OfflineSecureModeSettings.supportedMemoryLimitsMb,
                    _settings.memoryLimitMb,
                  }.toList()
                        ..sort())
                      .map(
                        (limitMb) => DropdownMenuItem<int>(
                          value: limitMb,
                          child: Text('$limitMb MB (${limitMb ~/ 1024} GB)'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _settings = _settings.copyWith(memoryLimitMb: value);
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _settings.inferenceEngine,
                  decoration: const InputDecoration(
                    labelText: '推論エンジン',
                    border: OutlineInputBorder(),
                  ),
                  items: OfflineSecureModeSettings.supportedInferenceEngines
                      .map(
                        (engine) => DropdownMenuItem<String>(
                          value: engine,
                          child: Text(engine),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _settings = _settings.copyWith(inferenceEngine: value);
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelPathController,
                  decoration: const InputDecoration(
                    labelText: 'ローカルモデルパス',
                    hintText: r'C:\models\pleias-rag.gguf',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _vectorDbPathController,
                  decoration: const InputDecoration(
                    labelText: 'ローカルベクトルDBパス',
                    hintText: r'C:\rag\lancedb',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _runtimeUrlController,
                  decoration: const InputDecoration(
                    labelText: 'ローカルRAGランタイムURL',
                    hintText: OfflineSecureModeSettings.defaultLocalRuntimeUrl,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey<String>('offline_save_button'),
                  onPressed: _saving ? null : _saveSettings,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('保存'),
                ),
                const SizedBox(height: 20),
                _AuditTrailSection(
                  entries: _auditEntries,
                  loading: _loadingAudit,
                  onRefresh: _loadAuditLogs,
                ),
              ],
            ),
    );
  }
}

class _AuditTrailSection extends StatelessWidget {
  final List<OfflineSecureModeAuditEntry> entries;
  final bool loading;
  final VoidCallback onRefresh;

  const _AuditTrailSection({
    required this.entries,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey<String>('offline_audit_section'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'セキュアモード監査証跡 (Supabase)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('offline_audit_refresh_button'),
                  tooltip: '監査証跡を更新',
                  onPressed: loading ? null : onRefresh,
                  icon: const Icon(Icons.history),
                ),
              ],
            ),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else if (entries.isEmpty)
              Text(
                '記録済みのセキュアモード監査証跡はまだありません。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...entries.take(5).map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        entry.externalApiBlocked
                            ? Icons.gpp_good_outlined
                            : Icons.cloud_done_outlined,
                      ),
                      title: Text('${entry.action} · ${entry.status}'),
                      subtitle: Text(
                        '${entry.provider} | ${entry.memoryLimitMb} MB'
                        '${entry.recordedAt.isEmpty ? '' : ' | ${entry.recordedAt}'}',
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final OfflineSecureModeSettings settings;

  const _StatusPanel({required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = settings.externalApiBlocked
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    final icon = settings.externalApiBlocked
        ? Icons.gpp_good_outlined
        : Icons.cloud_outlined;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _policyTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_runtimeText),
                  const SizedBox(height: 6),
                  Text('推論エンジン: ${settings.inferenceEngine}'),
                  const SizedBox(height: 6),
                  Text('ローカルRAG: ${settings.localRuntimeUrl}'),
                  const SizedBox(height: 6),
                  Text(
                    'メモリ上限ガード: ${settings.memoryLimitMb} MB (8GB RAM制約対応)',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _policyTitle {
    if (settings.externalApiBlocked) {
      return '外部API遮断中';
    }
    if (settings.enabled) {
      return 'オフラインON / 外部API許可';
    }
    return 'オンラインLLM許可';
  }

  String get _runtimeText {
    if (settings.localRuntimeConfigured) {
      return 'ローカルランタイム設定済み';
    }
    if (settings.enabled && settings.externalApiBlocked) {
      return 'ローカルモデルまたはベクトルDBが未設定です';
    }
    return 'ローカルランタイム未設定';
  }
}
