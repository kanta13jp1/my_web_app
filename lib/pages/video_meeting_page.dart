import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ビデオ会議管理ページ
/// video-meeting-manager Edge Function と連携 (Zoom/Google Meet/Teams競合)
class VideoMeetingPage extends StatefulWidget {
  const VideoMeetingPage({super.key});

  @override
  State<VideoMeetingPage> createState() => _VideoMeetingPageState();
}

class _VideoMeetingPageState extends State<VideoMeetingPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _rooms = [];
  List<dynamic> _minutes = [];
  List<dynamic> _actionItems = [];
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'video-meeting-manager',
        body: {'action': 'list'},
      );
      final data = res.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _rooms = (data['rooms'] as List?) ?? [];
          _minutes = (data['minutes'] as List?) ?? [];
          _actionItems = (data['action_items'] as List?) ?? [];
          _stats = data['stats'] as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createRoom() async {
    final nameCtrl = TextEditingController();
    final typeVal = ValueNotifier<String>('video');
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('会議ルームを作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: '会議名',
                hintText: '例: 週次チームミーティング',
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: typeVal,
              builder: (context, val, _) => DropdownButtonFormField<String>(
                initialValue: val,
                decoration: const InputDecoration(labelText: '会議タイプ'),
                items: const [
                  DropdownMenuItem(value: 'video', child: Text('ビデオ会議')),
                  DropdownMenuItem(value: 'audio', child: Text('音声のみ')),
                  DropdownMenuItem(value: 'webinar', child: Text('ウェビナー')),
                  DropdownMenuItem(
                    value: 'screen_share',
                    child: Text('画面共有'),
                  ),
                ],
                onChanged: (v) => typeVal.value = v ?? 'video',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _supabase.functions.invoke(
                  'video-meeting-manager',
                  body: {
                    'action': 'create_room',
                    'name': nameCtrl.text.trim(),
                    'type': typeVal.value,
                  },
                );
                await _fetchData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('会議ルームを作成しました')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('作成に失敗しました: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B35),
              foregroundColor: Colors.white,
            ),
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  Color _meetingTypeColor(String? type) {
    switch (type) {
      case 'video':
        return Color(0xFF3D5AFE);
      case 'audio':
        return Colors.green;
      case 'webinar':
        return Colors.purple;
      case 'screen_share':
        return Colors.orange;
      default:
        return Color(0xFF9CA3AF);
    }
  }

  IconData _meetingTypeIcon(String? type) {
    switch (type) {
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.mic;
      case 'webinar':
        return Icons.cast;
      case 'screen_share':
        return Icons.screen_share;
      default:
        return Icons.meeting_room;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('ビデオ会議'),
        backgroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _isLoading ? null : _fetchData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: '会議ルーム'),
            Tab(text: '議事録'),
            Tab(text: 'アクション'),
            Tab(text: '統計'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createRoom,
        backgroundColor: Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        tooltip: '会議を作成',
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchData,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRoomsTab(),
                    _buildMinutesTab(),
                    _buildActionItemsTab(),
                    _buildStatsTab(),
                  ],
                ),
    );
  }

  Widget _buildRoomsTab() {
    if (_rooms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 8),
            Text(
              '会議ルームがありません\n右下の＋ボタンで作成してください',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _rooms.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final room = _rooms[i] as Map<String, dynamic>;
        final type = room['type']?.toString();
        final participantCount = room['participant_count'] ?? 0;
        return Card(
          color: Color(0xFF1E1E1E),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _meetingTypeColor(type).withAlpha(30),
              child: Icon(
                _meetingTypeIcon(type),
                color: _meetingTypeColor(type),
              ),
            ),
            title: Text(room['name']?.toString() ?? '会議'),
            subtitle: Text(
              '参加者: $participantCount人  |  '
              '${room['status'] ?? 'inactive'}',
            ),
            trailing: room['status'] == 'active'
                ? const Chip(
                    label: Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: Colors.red,
                    padding: EdgeInsets.zero,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildMinutesTab() {
    if (_minutes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 48,
              color: Color(0xFF9CA3AF),
            ),
            SizedBox(height: 8),
            Text(
              '議事録がありません',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _minutes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final min = _minutes[i] as Map<String, dynamic>;
        return Card(
          color: Color(0xFF1E1E1E),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0x333D5AFE),
              child: Icon(Icons.description, color: Color(0xFF3D5AFE)),
            ),
            title: Text(min['meeting_name']?.toString() ?? '会議'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  min['summary']?.toString() ?? '要約なし',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (min['created_at'] != null)
                  Text(
                    min['created_at'].toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionItemsTab() {
    if (_actionItems.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 8),
            Text(
              'アクションアイテムがありません',
              style: TextStyle(color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _actionItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = _actionItems[i] as Map<String, dynamic>;
        final done = item['completed'] == true;
        return Card(
          color: Color(0xFF1E1E1E),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: done
                  ? Colors.green.withAlpha(30)
                  : Colors.orange.withAlpha(30),
              child: Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? Colors.green : Colors.orange,
              ),
            ),
            title: Text(
              item['title']?.toString() ?? 'アクション',
              style: TextStyle(
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              '担当: ${item['assignee'] ?? '未割り当て'}  |  '
              '期限: ${item['due_date'] ?? '-'}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsTab() {
    if (_stats == null) {
      return const Center(
        child: Text(
          '統計データがありません',
          style: TextStyle(color: Color(0xFF9CA3AF)),
        ),
      );
    }
    final items = [
      ('総会議数', _stats!['total_meetings']?.toString() ?? '0'),
      ('今月の会議', _stats!['meetings_this_month']?.toString() ?? '0'),
      ('平均参加者', '${_stats!['avg_participants'] ?? 0}人'),
      ('平均時間', '${_stats!['avg_duration_minutes'] ?? 0}分'),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.8,
          physics: const NeverScrollableScrollPhysics(),
          children: items.map((item) {
            return Card(
              color: Color(0xFF1E1E1E),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.$2,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3D5AFE),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.$1,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
