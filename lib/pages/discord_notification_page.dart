import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Discord 通知連携ページ (#72)
/// discord-notifications Edge Function と連携して Discord チャンネルに通知
class DiscordNotificationPage extends StatefulWidget {
  const DiscordNotificationPage({super.key});

  @override
  State<DiscordNotificationPage> createState() =>
      _DiscordNotificationPageState();
}

class _DiscordNotificationPageState extends State<DiscordNotificationPage> {
  final _supabase = Supabase.instance.client;
  final _webhookController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isTesting = false;
  String? _errorMessage;
  String? _successMessage;
  List<Map<String, dynamic>> _history = [];

  final Map<String, bool> _triggers = {
    'task_completed': true,
    'habit_achieved': true,
    'memo_created': false,
    'daily_summary': true,
    'feature_request': false,
    'goal_reached': true,
  };

  static const Map<String, String> _triggerLabels = {
    'task_completed': 'タスク完了',
    'habit_achieved': '習慣達成',
    'memo_created': 'メモ作成',
    'daily_summary': '日次サマリー',
    'feature_request': '機能リクエスト',
    'goal_reached': 'ゴール達成',
  };

  static const _discordColor = Color(0xFF5865F2);

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
        'lifestyle-hub',
        body: {'action': 'discord.get_config'},
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
    } catch (_) {
      // EF未デプロイ時も0件で正常表示
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
        'lifestyle-hub',
        body: {
          'action': 'discord.configure',
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
        'lifestyle-hub',
        body: {'action': 'discord.test'},
      );
      final data = res.data;
      if (mounted) {
        setState(
          () => _successMessage = data is Map && data['message'] != null
              ? data['message'].toString()
              : 'テスト通知を Discord に送信しました',
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
        title: const Text('Discord 通知連携'),
        backgroundColor: _discordColor,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
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
            _buildInfoBanner(),
            const SizedBox(height: 12),
            if (_errorMessage != null)
              _buildAlert(_errorMessage!, isError: true),
            if (_successMessage != null)
              _buildAlert(_successMessage!, isError: false),
            _buildWebhookCard(),
            const SizedBox(height: 12),
            _buildTriggerCard(),
            const SizedBox(height: 16),
            _buildActionRow(),
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
              ..._history.take(5).map((h) => _HistoryTile(history: h)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _discordColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _discordColor.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: _discordColor, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Discord サーバーの Webhook URL を設定すると、タスク完了・習慣達成などの通知を Discord チャンネルに自動送信できます。',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert(String message, {required bool isError}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isError
        ? (isDark ? const Color(0xFF3A1010) : const Color(0xFFFFEBEE))
        : (isDark ? const Color(0xFF0A1A0A) : const Color(0xFFE8F5E9));
    final border = isError
        ? (isDark ? const Color(0xFF8B2020) : const Color(0xFFEF9A9A))
        : (isDark ? const Color(0xFF1A5A1A) : const Color(0xFFA5D6A7));
    final fg = isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: fg,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: fg,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWebhookCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.webhook, color: _discordColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Webhook 設定',
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
                labelText: 'Discord Webhook URL',
                hintText: 'https://discord.com/api/webhooks/...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            const Text(
              'Discord サーバー設定 → 連携サービス → ウェブフック で作成できます',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black45,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTriggerCard() {
    return Card(
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
                title: Text(_triggerLabels[entry.key] ?? entry.key),
                value: entry.value,
                activeThumbColor: _discordColor,
                onChanged: (val) {
                  setState(() => _triggers[entry.key] = val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
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
              backgroundColor: _discordColor,
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
