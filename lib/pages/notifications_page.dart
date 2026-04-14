// lib/pages/notifications_page.dart
// アプリ内通知センター — notification-center Edge Function と連携
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  String _filter = 'all'; // 'all' | 'unread' | 'read'

  static const Map<String, _NotifMeta> _typeMeta = {
    'feature_update': _NotifMeta(Icons.new_releases, Color(0xFF6366F1), '新機能'),
    'achievement': _NotifMeta(Icons.emoji_events, Color(0xFFF59E0B), '実績'),
    'cs_reply': _NotifMeta(Icons.support_agent, Color(0xFF10B981), 'CS返信'),
    'system': _NotifMeta(Icons.info, Color(0xFF3B82F6), 'システム'),
    'marketing': _NotifMeta(Icons.campaign, Color(0xFFEC4899), 'お知らせ'),
    'blog_published': _NotifMeta(Icons.article, Color(0xFF8B5CF6), 'ブログ'),
    'agent_report': _NotifMeta(Icons.smart_toy, Color(0xFF06B6D4), 'エージェント'),
  };

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'core-hub',
        body: {'action': 'notification.list', 'filter': _filter},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _notifications = (data['notifications'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          _unreadCount = (data['unreadCount'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await _supabase.functions.invoke(
        'core-hub',
        body: {'action': 'notification.mark_read', 'id': id},
      );
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1 && _notifications[idx]['is_read'] == false) {
          _notifications[idx] = {..._notifications[idx], 'is_read': true};
          if (_unreadCount > 0) _unreadCount--;
        }
      });
    } catch (_) {
      // silent — ベストエフォート
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _supabase.functions.invoke(
        'core-hub',
        body: {'action': 'notification.mark_all'},
      );
      setState(() {
        _notifications =
            _notifications.map((n) => {...n, 'is_read': true}).toList();
        _unreadCount = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('すべて既読にしました'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _relativeTime(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'たった今';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
      if (diff.inHours < 24) return '${diff.inHours}時間前';
      if (diff.inDays < 7) return '${diff.inDays}日前';
      return DateFormat('MM/dd HH:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('通知センター'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            TextButton.icon(
              onPressed: _markAllRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('全既読'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: Column(
        children: [
          // フィルターチップ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'すべて',
                  selected: _filter == 'all',
                  onTap: () {
                    setState(() => _filter = 'all');
                    _fetchNotifications();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '未読',
                  selected: _filter == 'unread',
                  onTap: () {
                    setState(() => _filter = 'unread');
                    _fetchNotifications();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: '既読',
                  selected: _filter == 'read',
                  onTap: () {
                    setState(() => _filter = 'read');
                    _fetchNotifications();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text('読み込み失敗: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchNotifications,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }
    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              _filter == 'unread' ? '未読通知はありません' : '通知はありません',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) => _NotifTile(
          notif: _notifications[index],
          typeMeta: _typeMeta,
          relativeTime:
              _relativeTime(_notifications[index]['created_at'] as String?),
          onTap: () {
            final n = _notifications[index];
            if (n['is_read'] == false) _markRead(n['id'] as String);
            final link = n['link'] as String?;
            if (link != null && link.isNotEmpty) {
              Navigator.pushNamed(context, link);
            }
          },
        ),
      ),
    );
  }
}

class _NotifMeta {
  final IconData icon;
  final Color color;
  final String label;
  const _NotifMeta(this.icon, this.color, this.label);
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  final Map<String, _NotifMeta> typeMeta;
  final String relativeTime;
  final VoidCallback onTap;

  const _NotifTile({
    required this.notif,
    required this.typeMeta,
    required this.relativeTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = notif['type'] as String? ?? 'system';
    final isRead = notif['is_read'] as bool? ?? false;
    final meta = typeMeta[type] ??
        const _NotifMeta(Icons.notifications, Color(0xFF6B7280), 'その他');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead
            ? null
            : (isDark
                ? Colors.indigo.withValues(alpha: 0.08)
                : Colors.indigo.withValues(alpha: 0.04)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // アイコン
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(meta.icon, color: meta.color, size: 22),
            ),
            const SizedBox(width: 12),
            // 本文
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          meta.label,
                          style: TextStyle(
                            fontSize: 10,
                            color: meta.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const Spacer(),
                      Text(
                        relativeTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif['title'] as String? ?? '',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif['message'] as String? ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notif['link'] != null &&
                      (notif['link'] as String).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '→ タップして詳細を見る',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
