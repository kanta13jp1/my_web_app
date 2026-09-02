import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/voice_ai_settings_service.dart';

class VoiceAiGovernancePage extends StatefulWidget {
  const VoiceAiGovernancePage({
    super.key,
    this.service,
    this.supabaseClient,
    this.adminMode = false,
  });

  final VoiceAiSettingsService? service;
  final SupabaseClient? supabaseClient;
  final bool adminMode;

  @override
  State<VoiceAiGovernancePage> createState() => _VoiceAiGovernancePageState();
}

class _VoiceAiGovernancePageState extends State<VoiceAiGovernancePage> {
  late final VoiceAiSettingsService _service;

  VoiceAiSettings _settings = VoiceAiSettings.empty;
  List<VoiceAiUsageSummary> _usage = [];
  bool _loading = true;
  bool _saving = false;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? VoiceAiSettingsService(widget.supabaseClient);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final settings = await _service.loadSettings();
      final usage = await _service.loadUsageSummary();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _usage = usage;
        _status = '';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Failed to load: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleConsent(bool enabled) async {
    setState(() => _saving = true);
    try {
      final settings = await _service.updateTrainingConsent(enabled);
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _status = enabled
            ? 'Voice training consent is enabled.'
            : 'Voice training opt-out is enabled. Third-party voice calls are '
                'blocked unless an administrator has confirmed provider ZDR.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = 'Failed to save: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalChars = _usage.fold<int>(0, (sum, row) => sum + row.ttsChars);
    final totalSeconds = _usage.fold<double>(
      0,
      (sum, row) => sum + row.sttSeconds,
    );
    final totalCost = _usage.fold<double>(
      0,
      (sum, row) => sum + row.estimatedCostUsd,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.adminMode ? 'Voice AI cost monitor' : 'Voice AI governance',
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    value: _settings.trainingConsent,
                    onChanged: _saving ? null : _toggleConsent,
                    secondary: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Allow voice data training'),
                    subtitle: Text(
                      _settings.trainingConsent
                          ? 'Training consent is saved in Supabase.'
                          : 'Opt-out is active. Third-party voice calls require '
                              'administrator-confirmed provider ZDR.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _MetricStrip(
                    totalChars: totalChars,
                    totalSeconds: totalSeconds,
                    totalCost: totalCost,
                    blockedCount: _usage.fold<int>(
                      0,
                      (sum, row) => sum + row.blockedEventCount,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.graphic_eq_outlined),
                      title: Text('Realtime audio verification'),
                      subtitle: Text(
                        'Use the Site Guide voice-call control to exercise the '
                        'authenticated backend proxy and continuous PCM playback.',
                      ),
                    ),
                  ),
                  if (_status.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_status),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Usage summary',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  for (final row in _usage)
                    _UsageSummaryTile(row: row),
                  if (_usage.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('No voice usage yet.')),
                    ),
                ],
              ),
            ),
    );
  }
}

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({
    required this.totalChars,
    required this.totalSeconds,
    required this.totalCost,
    required this.blockedCount,
  });

  final int totalChars;
  final double totalSeconds;
  final double totalCost;
  final int blockedCount;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetricChip(label: 'TTS chars', value: totalChars.toString()),
        _MetricChip(label: 'STT sec', value: totalSeconds.toStringAsFixed(0)),
        _MetricChip(label: 'Est. USD', value: totalCost.toStringAsFixed(4)),
        _MetricChip(label: 'Blocked', value: blockedCount.toString()),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.monitor_heart_outlined, size: 18),
      label: Text('$label: $value'),
    );
  }
}

class _UsageSummaryTile extends StatelessWidget {
  const _UsageSummaryTile({required this.row});

  final VoiceAiUsageSummary row;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.graphic_eq_outlined),
        title: Text('${row.provider} / ${_formatDate(row.usageDate)}'),
        subtitle: Text(
          'chars ${row.ttsChars} / stt ${row.sttSeconds.toStringAsFixed(0)}s / '
          'TTFA ${row.avgTtfaMs.toStringAsFixed(0)}ms / '
          'chunk ${row.avgChunkLatencyMs.toStringAsFixed(0)}ms',
        ),
        trailing: Text('\$${row.estimatedCostUsd.toStringAsFixed(4)}'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
