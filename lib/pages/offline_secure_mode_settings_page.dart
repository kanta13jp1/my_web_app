import 'package:flutter/material.dart';

import '../services/offline_secure_mode_settings_service.dart';

class OfflineSecureModeSettingsPage extends StatefulWidget {
  final OfflineSecureModeSettingsService settingsService;

  const OfflineSecureModeSettingsPage({
    super.key,
    this.settingsService = const OfflineSecureModeSettingsService(),
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
  bool _loading = true;
  bool _saving = false;

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
    setState(() {
      _settings = saved;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('オフラインセキュアモード設定を保存しました')),
    );
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
              ],
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
