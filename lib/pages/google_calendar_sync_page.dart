import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Google カレンダー同期ページ
/// google-calendar-sync Edge Function と連携して予定を双方向同期
class GoogleCalendarSyncPage extends StatefulWidget {
  const GoogleCalendarSyncPage({super.key});

  @override
  State<GoogleCalendarSyncPage> createState() => _GoogleCalendarSyncPageState();
}

class _GoogleCalendarSyncPageState extends State<GoogleCalendarSyncPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  bool _connected = false;
  int _syncedCount = 0;
  String? _lastSyncAt;
  List<Map<String, dynamic>> _calendars = [];

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
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
        'enterprise-hub',
        body: {'action': 'calendar.status'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _connected = data['connected'] == true;
          _syncedCount = (data['synced_count'] as num?)?.toInt() ?? 0;
          _lastSyncAt = data['last_sync_at']?.toString();
          if (data['calendars'] is List) {
            _calendars = List<Map<String, dynamic>>.from(
              (data['calendars'] as List).whereType<Map>(),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '状態の取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sync() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'calendar.sync'},
      );
      final data = res.data;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data is Map && data['message'] != null
                  ? data['message'].toString()
                  : '同期が完了しました',
            ),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
      await _fetchStatus();
    } catch (e) {
      if (!mounted) return;
      if (mounted) setState(() => _errorMessage = '同期に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _supabase.functions.invoke(
        'enterprise-hub',
        body: {'action': 'calendar.connect_url'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google認証URLを取得しました。ブラウザで認証を完了してください。'),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '接続URLの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google カレンダー同期'),
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
              onPressed: _fetchStatus,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStatus,
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: _connected
                              ? const Color(0xFF34A853)
                              : const Color(0xFF9CA3AF),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Google カレンダー',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _connected
                                          ? const Color(0xFF34A853)
                                          : const Color(0xFF9CA3AF),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _connected ? '接続済み' : '未接続',
                                    style: TextStyle(
                                      color: _connected
                                          ? const Color(0xFF34A853)
                                          : const Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w500,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!_connected)
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _connect,
                            icon: const Icon(Icons.link, size: 16),
                            label: const Text('接続する'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4285F4),
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    if (_connected) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '同期済み予定数',
                            style: TextStyle(
                              color: Colors.black54,
                              height: 1.5,
                            ),
                          ),
                          Text(
                            '$_syncedCount 件',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                      if (_lastSyncAt != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '最終同期',
                              style: TextStyle(
                                color: Colors.black54,
                                height: 1.5,
                              ),
                            ),
                            Text(
                              _lastSyncAt!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _sync,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync, size: 16),
                          label: Text(_isSyncing ? '同期中...' : '今すぐ同期'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_connected && _calendars.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                '同期中のカレンダー',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              ..._calendars.map((cal) => _CalendarTile(calendar: cal)),
            ],
            const SizedBox(height: 24),
            const Card(
              color: Color(0xFFF0F9FF),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF0284C7),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '同期の仕組み',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    _FeatureItem(
                      icon: Icons.sync_alt,
                      text: 'アプリの予定 ↔ Google カレンダーを双方向同期',
                    ),
                    _FeatureItem(
                      icon: Icons.notifications_active,
                      text: '新規予定・更新を自動検知して即時反映',
                    ),
                    _FeatureItem(
                      icon: Icons.lock_outline,
                      text: 'OAuth 2.0 による安全な認証 — パスワード不要',
                    ),
                    _FeatureItem(
                      icon: Icons.calendar_view_week,
                      text: '複数カレンダーを選択して個別に同期設定可能',
                    ),
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

class _CalendarTile extends StatelessWidget {
  const _CalendarTile({required this.calendar});
  final Map<String, dynamic> calendar;

  @override
  Widget build(BuildContext context) {
    final colorHex =
        calendar['color']?.toString().replaceFirst('#', '') ?? '4285f4';
    Color tileColor;
    try {
      tileColor = Color(int.parse('FF$colorHex', radix: 16));
    } catch (_) {
      tileColor = const Color(0xFF4285F4);
    }
    return ListTile(
      leading: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: tileColor,
          shape: BoxShape.circle,
        ),
      ),
      title: Text(calendar['name']?.toString() ?? 'カレンダー'),
      subtitle: Text(
        '${calendar['event_count'] ?? 0} 件の予定',
        style: const TextStyle(
          fontSize: 12,
          height: 1.5,
        ),
      ),
      trailing: Switch(
        value: calendar['enabled'] == true,
        onChanged: null,
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF0284C7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
