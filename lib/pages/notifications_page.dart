// lib/pages/notifications_page.dart
// アプリ内通知センター — notification-center Edge Function と連携
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/browser_reminder_settings.dart';

String _safeStr(Object? value) => value == null ? '' : value.toString();

String _formatRelativeTime(Object? raw) {
  final iso = _safeStr(raw);
  if (iso.isEmpty) return '';
  try {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
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

class _NotifMeta {
  final IconData icon;
  final Color color;
  final String label;
  const _NotifMeta(this.icon, this.color, this.label);
}

const Map<String, _NotifMeta> _notifTypeMeta = {
  'feature_update': _NotifMeta(Icons.new_releases, Color(0xFF6366F1), '新機能'),
  'achievement': _NotifMeta(Icons.emoji_events, Color(0xFFF59E0B), '実績'),
  'cs_reply': _NotifMeta(Icons.support_agent, Color(0xFF10B981), 'CS返信'),
  'system': _NotifMeta(Icons.info, Color(0xFF3B82F6), 'システム'),
  'marketing': _NotifMeta(Icons.campaign, Color(0xFFEC4899), 'お知らせ'),
  'blog_published': _NotifMeta(Icons.article, Color(0xFF8B5CF6), 'ブログ'),
  'agent_report': _NotifMeta(Icons.smart_toy, Color(0xFF06B6D4), 'エージェント'),
  'life_capital':
      _NotifMeta(Icons.monitor_heart_outlined, Color(0xFFDC2626), 'ライフKPI'),
};

const _NotifMeta _fallbackNotifMeta = _NotifMeta(
  Icons.notifications,
  Color(0xFF6B7280),
  'その他',
);

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _requiresLogin = false;
  String? _error;
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  String _filter = 'all'; // 'all' | 'unread' | 'read'

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    _requiresLogin = false;
    if (_supabase.auth.currentUser == null) {
      if (!mounted) return;
      setState(() {
        _requiresLogin = true;
        _error = null;
        _notifications = [];
        _unreadCount = 0;
        _isLoading = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _requiresLogin = false;
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'core-hub',
        body: {'action': 'notification.list', 'filter': _filter},
      );
      if (!mounted) return;
      final data = response.data;
      if (data is Map<dynamic, dynamic>) {
        final raw = data['notifications'];
        final items = <Map<String, dynamic>>[];
        if (raw is List<dynamic>) {
          for (final item in raw) {
            if (item is Map<dynamic, dynamic>) {
              items.add(Map<String, dynamic>.from(item));
            }
          }
        }
        final rawUnread = data['unreadCount'];
        final unreadCount = rawUnread is num ? rawUnread.toInt() : 0;
        setState(() {
          _notifications = items;
          _unreadCount = unreadCount;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markRead(String id) async {
    if (id.isEmpty) return;
    try {
      await _supabase.functions.invoke(
        'core-hub',
        body: {'action': 'notification.mark_read', 'id': id},
      );
      if (!mounted) return;
      setState(() {
        final idx = _notifications.indexWhere((n) => _safeStr(n['id']) == id);
        if (idx != -1 && _notifications[idx]['is_read'] != true) {
          _notifications[idx] = {..._notifications[idx], 'is_read': true};
          if (_unreadCount > 0) _unreadCount--;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('既読の更新に失敗しました。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _supabase.functions.invoke(
        'core-hub',
        body: {'action': 'notification.mark_all'},
      );
      if (!mounted) return;
      setState(() {
        _notifications =
            _notifications.map((n) => {...n, 'is_read': true}).toList();
        _unreadCount = 0;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('すべて既読にしました'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF212121) : const Color(0xFFFAFAFA),
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
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            NotificationsMarkAllButton(onPressed: _markAllRead),
        ],
      ),
      body: Column(
        children: [
          const BrowserReminderSettingsTile(),
          // フィルターチップ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                NotificationFilterChip(
                  label: 'すべて',
                  selected: _filter == 'all',
                  onTap: () {
                    setState(() => _filter = 'all');
                    _fetchNotifications();
                  },
                ),
                const SizedBox(width: 8),
                NotificationFilterChip(
                  label: '未読',
                  selected: _filter == 'unread',
                  onTap: () {
                    setState(() => _filter = 'unread');
                    _fetchNotifications();
                  },
                ),
                const SizedBox(width: 8),
                NotificationFilterChip(
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
    if (_requiresLogin) {
      return NotificationsSignedOutState(
        onLogin: () => Navigator.of(context).pushNamed('/login'),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
        ),
      );
    }
    if (_notifications.isEmpty) {
      final emptyText = _filter == 'unread' ? '未読通知はありません' : '通知はありません';
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
              emptyText,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 16,
                height: 1.5,
              ),
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
        itemBuilder: (context, index) {
          final n = _notifications[index];
          return NotificationTile(
            notif: n,
            onTap: () {
              final id = _safeStr(n['id']);
              if (n['is_read'] != true && id.isNotEmpty) {
                _markRead(id);
              }
              final link = _safeStr(n['link']);
              if (link.isNotEmpty) {
                Navigator.pushNamed(context, link);
              }
            },
          );
        },
      ),
    );
  }
}

class NotificationsMarkAllButton extends StatelessWidget {
  final VoidCallback onPressed;

  const NotificationsMarkAllButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.done_all, size: 18),
      label: const Text('全既読'),
      style: TextButton.styleFrom(foregroundColor: onSurface),
    );
  }
}

class NotificationsSignedOutState extends StatelessWidget {
  final VoidCallback onLogin;

  const NotificationsSignedOutState({
    super.key,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      key: const Key('notifications_signed_out_state'),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 48,
              color: Color(0xFF4F46E5),
            ),
            const SizedBox(height: 16),
            Text(
              'ログインすると通知を確認できます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login),
              label: const Text('ログイン'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const NotificationFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final Color chipColor;
    if (selected) {
      chipColor = colorScheme.primary;
    } else {
      chipColor = colorScheme.surfaceContainerHighest;
    }
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? colorScheme.onPrimary : colorScheme.onSurface,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  final String? relativeTime;
  final VoidCallback onTap;

  const NotificationTile({
    super.key,
    required this.notif,
    this.relativeTime,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rawType = _safeStr(notif['type']);
    final type = rawType.isEmpty ? 'system' : rawType;
    final isRead = notif['is_read'] == true;
    final meta = _notifTypeMeta[type] ?? _fallbackNotifMeta;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeText = relativeTime ?? _formatRelativeTime(notif['created_at']);
    final title = _safeStr(notif['title']);
    final message = _safeStr(notif['message']);
    final link = _safeStr(notif['link']);
    final colorScheme = Theme.of(context).colorScheme;
    final titleWeight = isRead ? FontWeight.normal : FontWeight.bold;
    final unreadBg = isDark
        ? const Color(0xFF3D5AFE).withValues(alpha: 0.08)
        : const Color(0xFF3D5AFE).withValues(alpha: 0.04);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead ? null : unreadBg,
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
                            height: 1.5,
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
                        timeText,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: titleWeight,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (link.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '→ タップして詳細を見る',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.primary,
                        height: 1.5,
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
