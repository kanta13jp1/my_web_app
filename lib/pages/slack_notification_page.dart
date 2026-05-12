import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Slack 通知連携ページ
/// slack-notifications Edge Function と連携してタスク・メモ更新を Slack チャンネルに通知
class SlackNotificationPage extends StatefulWidget {
  const SlackNotificationPage({super.key});

  @override
  State<SlackNotificationPage> createState() => _SlackNotificationPageState();
}

class _SlackNotificationPageState extends State<SlackNotificationPage> {
  final _supabase = Supabase.instance.client;
  final _webhookController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _history = [];

  final Map<String, bool> _triggers = {
    'task_created': true,
    'task_completed': true,
    'memo_created': false,
    'habit_achieved': true,
    'daily_summary': false,
    'feature_request': false,
  };

  static const Map<String, String> _triggerLabels = {
    'task_created': 'タスク作成',
    'task_completed': 'タスク完了',
    'memo_created': 'メモ作成',
    'habit_achieved': '習慣達成',
    'daily_summary': '日次サマリー',
    'feature_request': '機能リクエスト',
  };

  @override
  void initState() {
    super.initState();
    _fetchConfig();
  }

  @override
  void dispose() {
    _webhookController.dispose();
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
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          if (data['webhook_url'] != null) {
            _webhookController.text = data['webhook_url'].toString();
          }
          if (data['triggers'] is Map) {
            final saved = Map<String, dynamic>.from(data['triggers'] as Map);
            for (final key in _triggers.keys) {
              if (saved.containsKey(key)) {
                _triggers[key] = saved[key] == true;
              }
            }
          }
          if (data['history'] is List) {
            _history = List<Map<String, dynamic>>.from(
              (data['history'] as List).whereType<Map>(),
            );
          }
        });
      }
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
        },
      );
      if (mounted) setState(() => _successMessage = '設定を保存しました');
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
        body: {'action': 'slack.test'},
      );
      final data = res.data;
      if (mounted) {
        setState(
          () => _successMessage = data is Map && data['message'] != null
              ? data['message'].toString()
              : 'テスト通知を送信しました',
        );
      }
      await _fetchConfig();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = 'テスト送信に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
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
              child: SizedBox(
                width: 20,
                height: 20,
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
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF3A1010)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF5A2020)
                          : const Color(0xFFEF9A9A),
                    ),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFC62828),
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0A1A0A)
                        : const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF388E3C),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: Color(0xFF388E3C),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.webhook,
                          color: Color(0xFF4A154B),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Slack Webhook 設定',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
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
                    const SizedBox(height: 8),
                    const Text(
                      'Slack App → Incoming Webhooks で取得できます',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '通知するイベント',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._triggers.entries.map(
                      (entry) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _triggerLabels[entry.key] ?? entry.key,
                        ),
                        value: entry.value,
                        activeThumbColor: const Color(0xFF4A154B),
                        onChanged: (val) {
                          setState(() => _triggers[entry.key] = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, size: 16),
                    label: Text(_isSaving ? '保存中...' : '設定を保存'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A154B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _test,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, size: 16),
                    label: Text(_isTesting ? '送信中...' : 'テスト送信'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                '最近の通知履歴',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ..._history.take(5).map(
                    (h) => _HistoryTile(history: h),
                  ),
            ],
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
    return Card(
      child: ListTile(
        leading: Icon(
          success ? Icons.check_circle : Icons.error_outline,
          color: success ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
          size: 20,
        ),
        title: Text(
          history['event']?.toString() ?? 'イベント',
          style: const TextStyle(
            fontSize: 14,
            height: 1.5,
          ),
        ),
        subtitle: Text(
          history['sent_at']?.toString() ?? '',
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
          ),
        ),
        trailing: Text(
          success ? '成功' : '失敗',
          style: TextStyle(
            color: success ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
