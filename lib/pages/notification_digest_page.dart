import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 通知ダイジェストページ
/// notification-digest Edge Function と連携して通知サマリーを表示
class NotificationDigestPage extends StatefulWidget {
  const NotificationDigestPage({super.key});

  @override
  State<NotificationDigestPage> createState() => _NotificationDigestPageState();
}

class _NotificationDigestPageState extends State<NotificationDigestPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _digest;

  @override
  void initState() {
    super.initState();
    _fetchDigest();
  }

  Future<void> _fetchDigest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'notification-digest',
        body: {'action': 'get_digest'},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() => _digest = data);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'ダイジェストの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendDigest() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.functions.invoke(
        'notification-digest',
        body: {'action': 'send_digest'},
      );
      await _fetchDigest();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'ダイジェスト送信に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知ダイジェスト'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchDigest,
          ),
          IconButton(
            icon: const Icon(Icons.send),
            tooltip: 'ダイジェスト送信',
            onPressed: _isLoading ? null : _sendDigest,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchDigest,
                          child: const Text('再試行'),
                        ),
                      ],
                    ),
                  ),
                )
              : _digest == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ダイジェストデータがありません',
                            style: TextStyle(
                              color:
                                  isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // サマリーカード
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.summarize,
                                      color: Color(0xFF6366F1),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '通知サマリー',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildStat(
                                  '未読通知',
                                  '${_digest!['unread_count'] ?? 0}件',
                                  Icons.notifications_active,
                                  Colors.orange,
                                  isDark,
                                ),
                                const SizedBox(height: 8),
                                _buildStat(
                                  '本日受信',
                                  '${_digest!['today_count'] ?? 0}件',
                                  Icons.today,
                                  Colors.blue,
                                  isDark,
                                ),
                                const SizedBox(height: 8),
                                _buildStat(
                                  '重要通知',
                                  '${_digest!['important_count'] ?? 0}件',
                                  Icons.priority_high,
                                  Colors.red,
                                  isDark,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // 通知リスト
                        if (_digest!['notifications'] is List) ...[
                          Text(
                            '最新通知',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[700],
                                ),
                          ),
                          const SizedBox(height: 8),
                          ...(_digest!['notifications'] as List)
                              .cast<Map<String, dynamic>>()
                              .map(
                                (n) => Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: Icon(
                                      n['is_read'] == true
                                          ? Icons.notifications_none
                                          : Icons.notifications,
                                      color: n['is_read'] == true
                                          ? Colors.grey
                                          : const Color(0xFF6366F1),
                                    ),
                                    title: Text(
                                      n['title']?.toString() ?? '',
                                      style: TextStyle(
                                        fontWeight: n['is_read'] == true
                                            ? FontWeight.normal
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      n['body']?.toString() ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ],
                    ),
    );
  }

  Widget _buildStat(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
