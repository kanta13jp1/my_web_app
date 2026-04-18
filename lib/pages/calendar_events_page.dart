import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

/// カレンダーイベントページ
/// calendar-events Edge Function と連携してイベントを管理
/// table_calendar による月次ビュー + 日付別イベントリスト
class CalendarEventsPage extends StatefulWidget {
  const CalendarEventsPage({super.key});

  @override
  State<CalendarEventsPage> createState() => _CalendarEventsPageState();
}

class _CalendarEventsPageState extends State<CalendarEventsPage> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;

  // キー: 'YYYY-MM-DD', 値: イベントリスト
  final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // 選択日のイベントリスト
  List<Map<String, dynamic>> get _selectedDayEvents {
    final key = _dateKey(_selectedDay);
    return _eventsByDate[key] ?? [];
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Color _eventColor(Map<String, dynamic> event) {
    final hex = event['color']?.toString().replaceFirst('#', '') ?? '4285f4';
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    return const Color(0xFF4285F4);
  }

  @override
  void initState() {
    super.initState();
    _fetchMonth(_focusedDay);
  }

  Future<void> _fetchMonth(DateTime month) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _supabase.functions.invoke(
        'calendar-events',
        method: HttpMethod.get,
        queryParameters: {
          'view': 'month',
          'year': month.year.toString(),
          'month': month.month.toString(),
        },
      );
      final data = res.data;
      final rawEvents = data is Map<String, dynamic> && data['events'] is List
          ? data['events'] as List
          : <dynamic>[];

      final newMap = <String, List<Map<String, dynamic>>>{};
      for (final e in rawEvents) {
        if (e is! Map) continue;
        final ev = Map<String, dynamic>.from(e);
        final startAt = ev['start_at']?.toString() ?? '';
        if (startAt.isEmpty) continue;
        final date = DateTime.tryParse(startAt);
        if (date == null) continue;
        final key = _dateKey(date);
        newMap.putIfAbsent(key, () => []).add(ev);
      }

      if (mounted) {
        setState(() {
          for (final key in newMap.keys) {
            _eventsByDate[key] = newMap[key]!;
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'イベントの取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createEvent({
    required String title,
    required DateTime startAt,
    String description = '',
    bool allDay = false,
    String color = '#4285f4',
  }) async {
    try {
      final end = allDay ? startAt : startAt.add(const Duration(hours: 1));
      await _supabase.functions.invoke(
        'calendar-events',
        body: {
          'action': 'create',
          'title': title,
          'description': description,
          'start_at': startAt.toIso8601String(),
          'end_at': end.toIso8601String(),
          'all_day': allDay,
          'color': color,
        },
      );
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'イベントの作成に失敗しました: $e');
      }
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await _supabase.functions.invoke(
        'calendar-events',
        body: {'action': 'delete', 'event_id': eventId},
      );
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'イベントの削除に失敗しました: $e');
      }
    }
  }

  List<Map<String, dynamic>> _eventsLoader(DateTime day) {
    return _eventsByDate[_dateKey(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('カレンダー'),
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
              onPressed: () => _fetchMonth(_focusedDay),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            MaterialBanner(
              content: Text(_errorMessage!),
              backgroundColor: Colors.red.shade50,
              actions: [
                TextButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            eventLoader: _eventsLoader,
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _fetchMonth(focusedDay);
            },
            calendarStyle: CalendarStyle(
              markerDecoration: const BoxDecoration(
                color: Color(0xFF4285F4),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonShowsNext: false,
              titleCentered: true,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${_selectedDay.month}月${_selectedDay.day}日のイベント',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${_selectedDayEvents.length}件',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedDayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 48,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'この日のイベントはありません',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _selectedDayEvents.length,
                    itemBuilder: (context, index) {
                      final event = _selectedDayEvents[index];
                      return _EventCard(
                        event: event,
                        color: _eventColor(event),
                        onDelete: () {
                          final eventId = event['event_id']?.toString() ?? '';
                          if (eventId.isEmpty) return;
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('削除確認'),
                              content: Text('「${event['title']}」を削除しますか？'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('キャンセル'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _deleteEvent(eventId);
                                  },
                                  child: const Text('削除'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventDialog(context),
        tooltip: 'イベントを追加',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var eventDate = _selectedDay;
    var allDay = true;
    final colors = ['#4285f4', '#ea4335', '#34a853', '#fbbc05', '#9334e6'];
    var selectedColor = colors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('イベントを追加'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'タイトル *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: '説明',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: eventDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => eventDate = picked);
                        }
                      },
                      child: Text(
                        '${eventDate.year}/${eventDate.month}/${eventDate.day}',
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: allDay,
                      onChanged: (v) =>
                          setDialogState(() => allDay = v ?? true),
                    ),
                    const Text('終日'),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('カラー:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: colors
                      .map(
                        (c) => GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(
                                int.parse(
                                  'FF${c.replaceFirst('#', '')}',
                                  radix: 16,
                                ),
                              ),
                              shape: BoxShape.circle,
                              border: selectedColor == c
                                  ? Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      width: 2.5,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(ctx);
                _createEvent(
                  title: title,
                  startAt: eventDate,
                  description: descCtrl.text.trim(),
                  allDay: allDay,
                  color: selectedColor,
                );
              },
              child: const Text('追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.color,
    required this.onDelete,
  });

  final Map<String, dynamic> event;
  final Color color;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = event['title']?.toString() ?? 'タイトルなし';
    final description = event['description']?.toString() ?? '';
    final startAt = event['start_at']?.toString() ?? '';
    final allDay = event['all_day'] == true;

    String timeLabel = '';
    if (!allDay && startAt.isNotEmpty) {
      final dt = DateTime.tryParse(startAt)?.toLocal();
      if (dt != null) {
        timeLabel =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } else {
      timeLabel = '終日';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.event, color: color, size: 20),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeLabel, style: const TextStyle(fontSize: 12)),
            if (description.isNotEmpty)
              Text(
                description,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          tooltip: '削除',
          onPressed: onDelete,
        ),
      ),
    );
  }
}
