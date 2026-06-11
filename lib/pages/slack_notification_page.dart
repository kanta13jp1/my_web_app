import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SlackNotificationPage extends StatefulWidget {
  const SlackNotificationPage({super.key, this.supabaseClient});

  final SupabaseClient? supabaseClient;

  @override
  State<SlackNotificationPage> createState() => _SlackNotificationPageState();
}

class _SlackNotificationPageState extends State<SlackNotificationPage> {
  late final SupabaseClient _supabase;
  final _webhookController = TextEditingController();
  final _teamIdController = TextEditingController(text: 'default');

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _approvals = [];
  bool _approvalRequired = true;

  final Map<String, bool> _triggers = {
    'task_created': true,
    'task_completed': true,
    'memo_created': false,
    'habit_achieved': true,
    'daily_summary': false,
    'feature_request': false,
  };

  final Map<String, bool> _connectorEnabled = {
    'slack': true,
    'discord': false,
    'notion': false,
    'asana': false,
    'gmail': false,
  };

  static const Map<String, String> _triggerLabels = {
    'task_created': 'タスク作成',
    'task_completed': 'タスク完了',
    'memo_created': 'メモ作成',
    'habit_achieved': '習慣達成',
    'daily_summary': '日次サマリー',
    'feature_request': '機能リクエスト',
  };

  static const Map<String, String> _connectorLabels = {
    'slack': 'Slack',
    'discord': 'Discord',
    'notion': 'Notion',
    'asana': 'Asana',
    'gmail': 'Gmail',
  };

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _fetchConfig();
  }

  @override
  void dispose() {
    _webhookController.dispose();
    _teamIdController.dispose();
    super.dispose();
  }

  Future<void> _fetchConfig() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'tools-hub',
        body: {'action': 'slack.get_config'},
      );
      final data = _asMap(res.data);
      if (data == null) return;
      setState(() {
        _webhookController.text = data['webhook_url']?.toString() ?? '';
        _teamIdController.text = data['team_id']?.toString() ?? 'default';
        _approvalRequired = data['approval_required'] != false;

        final savedTriggers = _asMap(data['triggers']);
        if (savedTriggers != null) {
          for (final key in _triggers.keys) {
            if (savedTriggers.containsKey(key)) {
              _triggers[key] = savedTriggers[key] == true;
            }
          }
        }

        final savedConnectors = _asMap(data['connector_enabled']);
        if (savedConnectors != null) {
          for (final key in _connectorEnabled.keys) {
            if (savedConnectors.containsKey(key)) {
              _connectorEnabled[key] = savedConnectors[key] == true;
            }
          }
        }

        _history = _mapList(data['history']);
        _approvals = _mapList(data['approvals']);
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '設定の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final url = _webhookController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Webhook URL を入力してください');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'slack.configure',
          'webhook_url': url,
          'triggers': _triggers,
          'team_id': _teamIdController.text.trim().isEmpty
              ? 'default'
              : _teamIdController.text.trim(),
          'approval_required': _approvalRequired,
          'connector_enabled': _connectorEnabled,
        },
      );
      if (mounted) setState(() => _successMessage = '設定を保存しました');
      await _fetchConfig();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '保存に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _test() async {
    setState(() {
      _isTesting = true;
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'slack.test',
          'actor_type': 'ai',
          'requested_scopes': ['send', 'external_share'],
        },
      );
      final data = _asMap(res.data);
      if (!mounted) return;
      setState(() {
        _successMessage = data?['approval_required'] == true
            ? 'テスト通知を承認キューに追加しました'
            : data?['message']?.toString() ?? 'テスト通知を送信しました';
      });
      await _fetchConfig();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'テスト通知に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  Future<void> _decideApproval(
    Map<String, dynamic> approval,
    String decision, {
    String? reviewNote,
    Map<String, dynamic>? revisedPayload,
  }) async {
    final id = approval['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });
    try {
      await _supabase.functions.invoke(
        'tools-hub',
        body: {
          'action': 'saas_approval.decide',
          'request_id': id,
          'decision': decision,
          'review_note': reviewNote ?? '',
          'revised_payload': revisedPayload,
          'execute': decision == 'approved',
        },
      );
      if (!mounted) return;
      setState(() {
        _successMessage = switch (decision) {
          'approved' => '承認し、実行しました',
          'rejected' => '拒否しました',
          _ => '修正依頼として戻しました',
        };
      });
      await _fetchConfig();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '承認操作に失敗しました: $e');
    }
  }

  Future<void> _requestRevision(Map<String, dynamic> approval) async {
    final payload = _asMap(approval['payload']) ?? {};
    final controller = TextEditingController(
      text: payload['text']?.toString() ?? '',
    );
    final noteController = TextEditingController();
    final revised = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('修正して再実行'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '送信内容',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: '修正メモ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop({
                'text': controller.text.trim(),
                'note': noteController.text.trim(),
              }),
              child: const Text('戻す'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    noteController.dispose();
    if (revised == null) return;
    final text = revised['text']?.toString() ?? '';
    await _decideApproval(
      approval,
      'revision_requested',
      reviewNote: revised['note']?.toString() ?? '',
      revisedPayload: {...payload, 'text': text},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slack 通知連携'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: '更新',
              onPressed: _fetchConfig,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchConfig,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null)
              _StatusBanner(
                message: _errorMessage!,
                icon: Icons.error_outline,
                color: const Color(0xFFC62828),
              ),
            if (_successMessage != null)
              _StatusBanner(
                message: _successMessage!,
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
              ),
            _settingsCard(context),
            const SizedBox(height: 12),
            _approvalCard(context),
            const SizedBox(height: 16),
            _actionButtons(),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                '最近の通知履歴',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._history.take(5).map((h) => _HistoryTile(history: h)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _settingsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.webhook, color: Color(0xFF4A154B), size: 20),
                SizedBox(width: 8),
                Text(
                  'Slack Webhook 設定',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _webhookController,
              decoration: const InputDecoration(
                labelText: 'Webhook URL',
                hintText: 'https://hooks.slack.com/services/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _teamIdController,
              decoration: const InputDecoration(
                labelText: 'チームID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.groups_outlined),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '通知イベント',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            ..._triggers.entries.map(
              (entry) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_triggerLabels[entry.key] ?? entry.key),
                value: entry.value,
                activeThumbColor: const Color(0xFF4A154B),
                onChanged: (val) => setState(() => _triggers[entry.key] = val),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _approvalCard(BuildContext context) {
    final pendingCount =
        _approvals.where((item) => item['status'] == 'pending').length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Human-in-the-loop 承認',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(label: Text('未承認 $pendingCount')),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('外部SaaS実行前に承認を必須にする'),
              value: _approvalRequired,
              onChanged: (value) => setState(() => _approvalRequired = value),
            ),
            const SizedBox(height: 8),
            const Text(
              'チーム別コネクタ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _connectorEnabled.entries.map((entry) {
                return FilterChip(
                  label: Text(_connectorLabels[entry.key] ?? entry.key),
                  selected: entry.value,
                  onSelected: (value) {
                    setState(() => _connectorEnabled[entry.key] = value);
                  },
                );
              }).toList(),
            ),
            const Divider(height: 28),
            if (_approvals.isEmpty)
              const Text('承認待ちの外部SaaSアクションはありません')
            else
              ..._approvals.take(10).map(_approvalTile),
          ],
        ),
      ),
    );
  }

  Widget _approvalTile(Map<String, dynamic> approval) {
    final status = approval['status']?.toString() ?? 'pending';
    final preview = _asMap(approval['preview']) ?? {};
    final text = preview['text']?.toString() ??
        approval['action_label']?.toString() ??
        '外部SaaSアクション';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  approval['action_label']?.toString() ?? 'External action',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                _statusLabel(status),
                style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, maxLines: 4, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(
            'provider: ${approval['provider'] ?? '-'} / team: ${approval['team_id'] ?? 'default'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _decideApproval(approval, 'approved'),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('承認'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _decideApproval(approval, 'rejected'),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('拒否'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _requestRevision(approval),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('修正'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save, size: 16),
            label: Text(_isSaving ? '保存中...' : '設定を保存'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isTesting ? null : _test,
            icon: _isTesting
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send, size: 16),
            label: Text(_isTesting ? '確認中...' : 'テスト通知'),
          ),
        ),
      ],
    );
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static String _statusLabel(String status) {
    return switch (status) {
      'approved' => '承認済み',
      'rejected' => '拒否',
      'revision_requested' => '修正依頼',
      'sent' => '送信済み',
      _ => '承認待ち',
    };
  }

  static Color _statusColor(String status) {
    return switch (status) {
      'approved' || 'sent' => const Color(0xFF2E7D32),
      'rejected' => const Color(0xFFC62828),
      'revision_requested' => const Color(0xFFEF6C00),
      _ => const Color(0xFF1565C0),
    };
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: color, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.history});

  final Map<String, dynamic> history;

  @override
  Widget build(BuildContext context) {
    final success = history['success'] == true;
    return ListTile(
      leading: Icon(
        success ? Icons.check_circle : Icons.error_outline,
        color: success ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      ),
      title: Text(history['event']?.toString() ?? '通知'),
      subtitle: Text(history['sent_at']?.toString() ?? ''),
      trailing: Text(success ? '成功' : '失敗'),
    );
  }
}
