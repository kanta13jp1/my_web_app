import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_app/utils/tab_route_url_sync.dart';

/// 勤怠・時間追跡ページ
/// app-hub:time.* と連携して作業時間を管理
/// ジョブカン・Toggl・Clockify競合
class TimeTrackerPage extends StatefulWidget {
  const TimeTrackerPage({super.key});

  @override
  State<TimeTrackerPage> createState() => _TimeTrackerPageState();
}

class _TimeTrackerPageState extends State<TimeTrackerPage>
    with SingleTickerProviderStateMixin, TabRouteUrlSync {
  @override
  List<String> get tabUrlSlugs =>
      const <String>['entries', 'projects', 'clock'];

  @override
  TabController get tabUrlController => _tabController;

  final _supabase = Supabase.instance.client;
  late final TabController _tabController;
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _projects = [];
  double _totalHours = 0;
  bool _overtimeAlert = false;
  String _view = 'today';
  final _projectCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchEntries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _projectCtrl.dispose();
    _hoursCtrl.dispose();
    _memoCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchEntries() async {
    if (_supabase.auth.currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'time.list', 'view': _view},
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        setState(() {
          _entries = data['entries'] is List
              ? (data['entries'] as List).cast<Map<String, dynamic>>()
              : [];
          _totalHours = (data['totalHours'] as num?)?.toDouble() ?? 0;
          _overtimeAlert = data['overtimeAlert'] as bool? ?? false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = '勤怠データの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProjects() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'time.projects'},
      );
      final data = response.data;
      if (data is Map<String, dynamic> && data['projects'] is List) {
        setState(
          () => _projects =
              (data['projects'] as List).cast<Map<String, dynamic>>(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'プロジェクトデータの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _clockAction(String action) async {
    try {
      await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'time.clock', 'type': action},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action == 'clock_in' ? '出勤しました' : '退勤しました')),
        );
      }
      await _fetchEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打刻に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _logHours() async {
    _projectCtrl.clear();
    _hoursCtrl.clear();
    _memoCtrl.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('作業時間を記録'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _projectCtrl,
              decoration: const InputDecoration(labelText: 'プロジェクト名'),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hoursCtrl,
              decoration: const InputDecoration(
                labelText: '作業時間 (例: 2.5)',
                suffixText: 'h',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _memoCtrl,
              decoration: const InputDecoration(labelText: 'メモ (任意)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('記録'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final hours = double.tryParse(_hoursCtrl.text.trim()) ?? 0;
    if (_projectCtrl.text.trim().isEmpty || hours <= 0) return;
    try {
      await _supabase.functions.invoke(
        'app-hub',
        body: {
          'action': 'time.log_hours',
          'project': _projectCtrl.text.trim(),
          'hours': hours,
          'memo': _memoCtrl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('作業時間を記録しました')),
        );
      }
      await _fetchEntries();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('記録に失敗しました: $e')),
        );
      }
    }
  }

  String _viewLabel(String v) {
    switch (v) {
      case 'today':
        return '今日';
      case 'week':
        return '今週';
      case 'month':
        return '今月';
      default:
        return v;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        title: const Text('勤怠・時間追跡'),
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (i) {
            if (i == 1) _fetchProjects();
          },
          tabs: const [
            Tab(icon: Icon(Icons.access_time), text: '勤怠記録'),
            Tab(icon: Icon(Icons.bar_chart), text: 'プロジェクト'),
            Tab(icon: Icon(Icons.punch_clock), text: '打刻'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _fetchEntries,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _logHours,
        backgroundColor: const Color(0xFFFF6B35),
        tooltip: '作業時間を記録',
        child: const Icon(Icons.add, color: Colors.white),
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
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _fetchEntries,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEntriesTab(),
                    _buildProjectsTab(),
                    _buildClockTab(),
                  ],
                ),
    );
  }

  Widget _buildEntriesTab() {
    return Column(
      children: [
        // KPI header
        Container(
          color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // View selector
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'today', label: Text('今日')),
                  ButtonSegment(value: 'week', label: Text('今週')),
                  ButtonSegment(value: 'month', label: Text('今月')),
                ],
                selected: {_view},
                onSelectionChanged: (s) {
                  setState(() => _view = s.first);
                  _fetchEntries();
                },
                style: ButtonStyle(
                  minimumSize: WidgetStateProperty.all(const Size(60, 32)),
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_totalHours.toStringAsFixed(1)}h',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0EA5E9),
                      height: 1.5,
                    ),
                  ),
                  Text(
                    _viewLabel(_view),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_overtimeAlert)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFFFE0B2),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF6B35),
                ),
                SizedBox(width: 8),
                Text(
                  '残業時間が上限に近づいています',
                  style: TextStyle(
                    color: Color(0xFFFF6B35),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: _entries.isEmpty
              ? const Center(
                  child: Text(
                    '記録がありません',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      height: 1.5,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final project = entry['project']?.toString() ?? '未分類';
                    final hours = (entry['hours'] as num?)?.toDouble() ?? 0;
                    final type = entry['type']?.toString() ?? '';
                    final memo = entry['memo']?.toString() ?? '';
                    final recordedAt = entry['recordedAt']?.toString() ?? '';
                    return Card(
                      color: const Color(0xFF1E1E1E),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: type == 'clock_in'
                              ? const Color(0xFFC8E6C9)
                              : type == 'clock_out'
                                  ? const Color(0xFFFFCDD2)
                                  : const Color(0xFF0EA5E9)
                                      .withValues(alpha: 0.15),
                          child: Icon(
                            type == 'clock_in'
                                ? Icons.login
                                : type == 'clock_out'
                                    ? Icons.logout
                                    : Icons.schedule,
                            color: type == 'clock_in'
                                ? const Color(0xFF4CAF50)
                                : type == 'clock_out'
                                    ? const Color(0xFFE53935)
                                    : const Color(0xFF0EA5E9),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          type == 'clock_in'
                              ? '出勤'
                              : type == 'clock_out'
                                  ? '退勤'
                                  : project,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            height: 1.5,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hours > 0)
                              Text(
                                '${hours.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  color: Color(0xFF0EA5E9),
                                  height: 1.5,
                                ),
                              ),
                            if (memo.isNotEmpty)
                              Text(
                                memo,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                          ],
                        ),
                        trailing: recordedAt.isNotEmpty
                            ? Text(
                                recordedAt.length > 10
                                    ? recordedAt.substring(0, 10)
                                    : recordedAt,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                  height: 1.5,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProjectsTab() {
    if (_projects.isEmpty) {
      return const Center(
        child: Text(
          'プロジェクトデータがありません',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            height: 1.5,
          ),
        ),
      );
    }
    final maxHours = _projects.fold<double>(0, (m, p) {
      final h = (p['hours'] as num?)?.toDouble() ?? 0;
      return h > m ? h : m;
    });
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final proj = _projects[index];
        final name = proj['name']?.toString() ?? '未分類';
        final hours = (proj['hours'] as num?)?.toDouble() ?? 0;
        final ratio = maxHours > 0 ? hours / maxHours : 0.0;
        final colors = [
          const Color(0xFF0EA5E9),
          const Color(0xFF6366F1),
          const Color(0xFF10B981),
          const Color(0xFFF59E0B),
          const Color(0xFFEF4444),
        ];
        final color = colors[index % colors.length];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                  ),
                  Text(
                    '${hours.toStringAsFixed(1)}h',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: ratio.toDouble(),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClockTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.punch_clock, size: 80, color: Color(0xFF0EA5E9)),
          const SizedBox(height: 24),
          const Text(
            '出退勤打刻',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ジョブカン競合の勤怠管理機能',
            style: TextStyle(
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _clockAction('clock_in'),
                  icon: const Icon(Icons.login),
                  label: const Text('出勤'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _clockAction('clock_out'),
                  icon: const Icon(Icons.logout),
                  label: const Text('退勤'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _logHours,
            icon: const Icon(Icons.add),
            label: const Text('作業時間を手動記録'),
          ),
        ],
      ),
    );
  }
}
