import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

/// カレンダーイベントページ
/// calendar-events Edge Function と連携してイベントを管理
/// table_calendar による月次ビュー + 日付別イベントリスト
class CalendarEventsPage extends StatefulWidget {
  const CalendarEventsPage({super.key, SupabaseClient? supabaseClient})
    : _supabaseClient = supabaseClient;

  final SupabaseClient? _supabaseClient;

  @override
  State<CalendarEventsPage> createState() => _CalendarEventsPageState();
}

enum _CalendarView { month, week, day }

String _formatClock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

DateTime? _eventDateTime(Map<String, dynamic> event, String key) {
  final value = event[key]?.toString() ?? '';
  if (value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

bool _eventIsAllDay(Map<String, dynamic> event) => event['all_day'] == true;

String _eventTitle(Map<String, dynamic> event) =>
    event['title']?.toString().trim().isNotEmpty == true
    ? event['title'].toString()
    : 'Untitled';

String _eventTimeLabel(Map<String, dynamic> event) {
  if (_eventIsAllDay(event)) return 'All-day';
  final start = _eventDateTime(event, 'start_at');
  final end = _eventDateTime(event, 'end_at');
  if (start == null) return '';
  if (end == null) return _formatClock(start);
  return '${_formatClock(start)} - ${_formatClock(end)}';
}

String _formatDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime d) => '${_formatDate(d)} ${_formatClock(d)}';

String _eventDateTimeLabel(Map<String, dynamic> event) {
  final start = _eventDateTime(event, 'start_at');
  final end = _eventDateTime(event, 'end_at');
  if (start == null) return 'No start time';
  if (_eventIsAllDay(event)) return '${_formatDate(start)} All-day';
  if (end == null) return _formatDateTime(start);
  final endLabel =
      start.year == end.year && start.month == end.month && start.day == end.day
      ? _formatClock(end)
      : _formatDateTime(end);
  return '${_formatDateTime(start)} - $endLabel';
}

String _eventColorHex(Map<String, dynamic> event) {
  final raw = event['color']?.toString().trim();
  if (raw == null || raw.isEmpty) return '#4285f4';
  final normalized = raw.startsWith('#') ? raw : '#$raw';
  final lower = normalized.toLowerCase();
  return RegExp(r'^#[0-9a-f]{6}$').hasMatch(lower) ? lower : '#4285f4';
}

typedef _CalendarFeatureLinkOption = ({
  String label,
  String path,
  List<String> keywords,
});

const List<_CalendarFeatureLinkOption> _calendarFeatureLinkOptions = [
  (
    label: '資産管理',
    path: '/asset-management',
    keywords: ['資産管理', '資産', '投資', '家計', '財務', 'asset', 'finance'],
  ),
  (label: 'ノート', path: '/note-list', keywords: ['ノート', 'メモ', 'note']),
];

@visibleForTesting
String? inferCalendarEventFeatureLinkUrl(String title, String description) {
  final text = '$title $description'.toLowerCase();
  for (final option in _calendarFeatureLinkOptions) {
    for (final keyword in option.keywords) {
      if (text.contains(keyword.toLowerCase())) return option.path;
    }
  }
  return null;
}

@visibleForTesting
String? normalizeCalendarEventFeatureLinkUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  for (final option in _calendarFeatureLinkOptions) {
    if (value == option.label ||
        value == option.path ||
        value == option.path.replaceFirst('/', '')) {
      return option.path;
    }
  }

  if (value.startsWith('//')) return null;
  if (value.startsWith('/')) return value;

  final parsed = Uri.tryParse(value);
  if (parsed != null && parsed.hasScheme) {
    final scheme = parsed.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') return value;
    return null;
  }

  if (RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_/-]*$').hasMatch(value)) {
    return '/$value';
  }
  return null;
}

String? _eventFeatureLinkUrl(Map<String, dynamic> event) {
  const keys = [
    'feature_link_url',
    'featureLinkUrl',
    'feature_url',
    'feature_path',
    'link_url',
    'url',
  ];
  for (final key in keys) {
    final normalized = normalizeCalendarEventFeatureLinkUrl(
      event[key]?.toString(),
    );
    if (normalized != null) return normalized;
  }
  return null;
}

String _eventFeatureLinkLabel(Map<String, dynamic> event, String url) {
  final storedLabel = event['feature_link_label']?.toString().trim();
  if (storedLabel != null && storedLabel.isNotEmpty) return storedLabel;

  for (final option in _calendarFeatureLinkOptions) {
    if (url == option.path) return option.label;
  }
  return 'リンク';
}

@visibleForTesting
List<Map<String, dynamic>> sortCalendarEventsForDisplay(
  Iterable<Map<String, dynamic>> events,
) {
  return events.toList()..sort(_compareCalendarEventsForDisplay);
}

int _compareCalendarEventsForDisplay(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
) {
  final aAllDay = _eventIsAllDay(a);
  final bAllDay = _eventIsAllDay(b);
  if (aAllDay != bAllDay) return aAllDay ? -1 : 1;

  final byStart = _compareNullableDateTime(
    _eventDateTime(a, 'start_at'),
    _eventDateTime(b, 'start_at'),
  );
  if (byStart != 0) return byStart;

  final byEnd = _compareNullableDateTime(
    _eventDateTime(a, 'end_at'),
    _eventDateTime(b, 'end_at'),
  );
  if (byEnd != 0) return byEnd;

  return _eventTitle(a).compareTo(_eventTitle(b));
}

int _compareNullableDateTime(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

class _CalendarEventsPageState extends State<CalendarEventsPage> {
  late final SupabaseClient _supabase =
      widget._supabaseClient ?? Supabase.instance.client;

  bool _isLoading = false;
  String? _errorMessage;

  // キー: 'YYYY-MM-DD', 値: イベントリスト
  final Map<String, List<Map<String, dynamic>>> _eventsByDate = {};

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  _CalendarView _calendarView = _CalendarView.month;

  // 選択日のイベントリスト
  List<Map<String, dynamic>> get _selectedDayEvents {
    final key = _dateKey(_selectedDay);
    return sortCalendarEventsForDisplay(_eventsByDate[key] ?? []);
  }

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Color _eventColor(Map<String, dynamic> event) {
    final hex = _eventColorHex(event).replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  void initState() {
    super.initState();
    _fetchMonth(_focusedDay);
  }

  Future<void> _fetchMonth(DateTime month) async {
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
        'app-hub',
        body: {'action': 'calendar.list'},
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
          _eventsByDate
            ..clear()
            ..addAll(newMap);
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
    DateTime? endAt,
    String description = '',
    bool allDay = false,
    String color = '#4285f4',
    String? featureLinkUrl,
  }) async {
    try {
      final end = allDay
          ? startAt
          : (endAt ?? startAt.add(const Duration(hours: 1)));
      final body = <String, dynamic>{
        'action': 'calendar.create',
        'title': title,
        'description': description,
        'start_at': startAt.toIso8601String(),
        'end_at': end.toIso8601String(),
        'all_day': allDay,
        'color': color,
      };
      final normalizedLink = normalizeCalendarEventFeatureLinkUrl(
        featureLinkUrl,
      );
      if (normalizedLink != null) {
        body['feature_link_url'] = normalizedLink;
      }
      await _supabase.functions.invoke('app-hub', body: body);
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'イベントの作成に失敗しました: $e');
      }
    }
  }

  Future<void> _updateEvent({
    required String eventId,
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    String description = '',
    bool allDay = false,
    String color = '#4285f4',
    String? featureLinkUrl,
    bool updateFeatureLink = false,
  }) async {
    if (eventId.isEmpty) {
      setState(() => _errorMessage = 'Event id is missing.');
      return;
    }
    try {
      final end = allDay
          ? startAt
          : (endAt ?? startAt.add(const Duration(hours: 1)));
      final body = <String, dynamic>{
        'action': 'calendar.update',
        'id': eventId,
        'title': title,
        'description': description,
        'start_at': startAt.toIso8601String(),
        'end_at': end.toIso8601String(),
        'all_day': allDay,
        'color': color,
      };
      if (updateFeatureLink) {
        body['feature_link_url'] =
            normalizeCalendarEventFeatureLinkUrl(featureLinkUrl) ?? '';
      }
      await _supabase.functions.invoke('app-hub', body: body);
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to update event: $e');
      }
    }
  }

  Future<void> _deleteEvent(String eventId) async {
    try {
      await _supabase.functions.invoke(
        'app-hub',
        body: {'action': 'calendar.delete', 'id': eventId},
      );
      await _fetchMonth(_focusedDay);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'イベントの削除に失敗しました: $e');
      }
    }
  }

  List<Map<String, dynamic>> _eventsLoader(DateTime day) {
    return sortCalendarEventsForDisplay(_eventsByDate[_dateKey(day)] ?? []);
  }

  void _setCalendarView(_CalendarView view) {
    setState(() {
      _calendarView = view;
      _calendarFormat = view == _CalendarView.week
          ? CalendarFormat.week
          : CalendarFormat.month;
      if (view == _CalendarView.day) {
        _focusedDay = _selectedDay;
      }
    });
  }

  void _moveSelectedDay(int deltaDays) {
    final next = _selectedDay.add(Duration(days: deltaDays));
    setState(() {
      _selectedDay = next;
      _focusedDay = next;
    });
    _fetchMonth(next);
  }

  void _confirmDeleteEvent(BuildContext context, Map<String, dynamic> event) {
    final eventId = event['event_id']?.toString() ?? '';
    if (eventId.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${_eventTitle(event)}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
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
  }

  String _eventDetailsText(Map<String, dynamic> event) {
    final buffer = StringBuffer()
      ..writeln(_eventTitle(event))
      ..writeln(_eventDateTimeLabel(event));
    final description = event['description']?.toString().trim() ?? '';
    if (description.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(description);
    }
    buffer
      ..writeln()
      ..writeln('Color: ${_eventColorHex(event)}');
    final featureLinkUrl = _eventFeatureLinkUrl(event);
    if (featureLinkUrl != null) {
      buffer.writeln('Link: $featureLinkUrl');
    }
    final eventId = event['event_id']?.toString() ?? '';
    if (eventId.isNotEmpty) {
      buffer.writeln('Event ID: $eventId');
    }
    return buffer.toString().trim();
  }

  String _metadataValue(Object? value) {
    if (value == null) return '-';
    if (value is DateTime) return value.toIso8601String();
    return value.toString();
  }

  List<({String label, String value})> _eventMetadataRows(
    Map<String, dynamic> event,
  ) {
    final entries = event.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return [
      for (final entry in entries)
        (label: entry.key, value: _metadataValue(entry.value)),
    ];
  }

  Future<void> _copyEventDetails(
    BuildContext context,
    Map<String, dynamic> event,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _eventDetailsText(event)));
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Event details copied')),
    );
  }

  Future<void> _shareEventDetails(Map<String, dynamic> event) async {
    await SharePlus.instance.share(
      ShareParams(text: _eventDetailsText(event), subject: _eventTitle(event)),
    );
  }

  Future<void> _handleEventTap(
    BuildContext context,
    Map<String, dynamic> event,
  ) async {
    if (_eventFeatureLinkUrl(event) != null) {
      await _openEventLink(context, event);
      return;
    }
    if (context.mounted) {
      _showEventDetailsSheet(context, event);
    }
  }

  Future<void> _openEventLink(
    BuildContext context,
    Map<String, dynamic> event,
  ) async {
    final rawUrl = _eventFeatureLinkUrl(event);
    if (rawUrl == null) {
      if (context.mounted) _showEventDetailsSheet(context, event);
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(rawUrl).hasScheme
        ? Uri.parse(rawUrl)
        : Uri.base.resolve(rawUrl);
    try {
      final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
      if (!opened && mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('リンクを開けませんでした: $rawUrl')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('リンクを開けませんでした: $e')));
      }
    }
  }

  void _showEventDetailsSheet(
    BuildContext context,
    Map<String, dynamic> event,
  ) {
    final color = _eventColor(event);
    final description = event['description']?.toString().trim() ?? '';
    final featureLinkUrl = _eventFeatureLinkUrl(event);
    final featureLinkLabel = featureLinkUrl == null
        ? null
        : _eventFeatureLinkLabel(event, featureLinkUrl);
    final metadataRows = _eventMetadataRows(event);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.16),
                      child: Icon(Icons.event, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _eventTitle(event),
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _eventDateTimeLabel(event),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Description', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(description, style: theme.textTheme.bodyMedium),
                ],
                if (featureLinkUrl != null) ...[
                  const SizedBox(height: 16),
                  Text('リンク', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 4),
                  SelectableText(
                    featureLinkUrl,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _eventColorHex(event),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (featureLinkUrl != null)
                      FilledButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: Text('$featureLinkLabelを開く'),
                        onPressed: () {
                          Navigator.pop(sheetContext);
                          _openEventLink(context, event);
                        },
                      ),
                    FilledButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showEditEventDialog(context, event);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _confirmDeleteEvent(context, event);
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.content_copy),
                      label: const Text('Copy'),
                      onPressed: () => _copyEventDetails(sheetContext, event),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share'),
                      onPressed: () => _shareEventDetails(event),
                    ),
                  ],
                ),
                if (metadataRows.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Metadata', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        for (final row in metadataRows)
                          _EventMetadataRow(label: row.label, value: row.value),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _CalendarViewSwitcher(
            selectedView: _calendarView,
            onChanged: _setCalendarView,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            MaterialBanner(
              content: Text(_errorMessage!),
              backgroundColor: const Color(0xFFFFEBEE),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _errorMessage = null),
                  child: const Text('閉じる'),
                ),
              ],
            ),
          if (_calendarView != _CalendarView.day)
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
                setState(() {
                  _calendarFormat = format;
                  _calendarView = format == CalendarFormat.week
                      ? _CalendarView.week
                      : _CalendarView.month;
                });
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
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            )
          else
            _DayViewHeader(
              selectedDay: _selectedDay,
              onPreviousDay: () => _moveSelectedDay(-1),
              onNextDay: () => _moveSelectedDay(1),
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
            child: _calendarView == _CalendarView.day
                ? _DayTimelineView(
                    selectedDay: _selectedDay,
                    events: _selectedDayEvents,
                    onTap: (event) => _handleEventTap(context, event),
                    onDetails: (event) =>
                        _showEventDetailsSheet(context, event),
                    onDelete: (event) => _confirmDeleteEvent(context, event),
                  )
                : _selectedDayEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 48,
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'この日のイベントはありません',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            height: 1.5,
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
                        onTap: () => _handleEventTap(context, event),
                        onLongPress: () =>
                            _showEventDetailsSheet(context, event),
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
                                    backgroundColor: const Color(0xFFE53935),
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
    _showEventDialog(context);
  }

  void _showEditEventDialog(BuildContext context, Map<String, dynamic> event) {
    _showEventDialog(context, event: event);
  }

  void _showEventDialog(BuildContext context, {Map<String, dynamic>? event}) {
    final isEditing = event != null;
    final eventId = event?['event_id']?.toString() ?? '';
    final initialStart = event == null
        ? _selectedDay
        : (_eventDateTime(event, 'start_at') ?? _selectedDay);
    final initialEnd = event == null
        ? initialStart.add(const Duration(hours: 1))
        : (_eventDateTime(event, 'end_at') ??
              initialStart.add(const Duration(hours: 1)));
    final titleCtrl = TextEditingController(
      text: event?['title']?.toString() ?? '',
    );
    final descCtrl = TextEditingController(
      text: event?['description']?.toString() ?? '',
    );
    final initialFeatureLinkUrl = event == null
        ? ''
        : (_eventFeatureLinkUrl(event) ?? '');
    final linkCtrl = TextEditingController(text: initialFeatureLinkUrl);
    var eventDate = DateTime(
      initialStart.year,
      initialStart.month,
      initialStart.day,
    );
    var allDay = event == null ? false : _eventIsAllDay(event);
    var startTime = TimeOfDay.fromDateTime(initialStart);
    var endTime = TimeOfDay.fromDateTime(initialEnd);
    final colors = ['#4285f4', '#ea4335', '#34a853', '#fbbc05', '#9334e6'];
    var selectedColor = event == null ? colors.first : _eventColorHex(event);
    if (!colors.contains(selectedColor)) {
      selectedColor = colors.first;
    }

    String fmtTime(TimeOfDay t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    void applySuggestedFeatureLink() {
      if (linkCtrl.text.trim().isNotEmpty) return;
      final suggested = inferCalendarEventFeatureLinkUrl(
        titleCtrl.text,
        descCtrl.text,
      );
      if (suggested != null) linkCtrl.text = suggested;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'イベントを編集' : 'イベントを追加'),
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
                  onChanged: (_) => setDialogState(applySuggestedFeatureLink),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: '説明',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onChanged: (_) => setDialogState(applySuggestedFeatureLink),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: linkCtrl,
                  decoration: const InputDecoration(
                    labelText: '開くリンク（任意）',
                    hintText: '/asset-management',
                    prefixIcon: Icon(Icons.open_in_new),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in _calendarFeatureLinkOptions)
                      ActionChip(
                        avatar: const Icon(Icons.link, size: 16),
                        label: Text(option.label),
                        onPressed: () =>
                            setDialogState(() => linkCtrl.text = option.path),
                      ),
                  ],
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
                          setDialogState(() => allDay = v ?? false),
                    ),
                    const Text('終日'),
                  ],
                ),
                if (!allDay) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 18),
                      const SizedBox(width: 8),
                      const Text('開始'),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setDialogState(() {
                              startTime = picked;
                              final startMinutes =
                                  picked.hour * 60 + picked.minute;
                              final endMinutes =
                                  endTime.hour * 60 + endTime.minute;
                              if (endMinutes <= startMinutes) {
                                final next = startMinutes + 60;
                                endTime = TimeOfDay(
                                  hour: (next ~/ 60) % 24,
                                  minute: next % 60,
                                );
                              }
                            });
                          }
                        },
                        child: Text(fmtTime(startTime)),
                      ),
                      const SizedBox(width: 8),
                      const Text('終了'),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setDialogState(() => endTime = picked);
                          }
                        },
                        child: Text(fmtTime(endTime)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                const Text('カラー:', style: TextStyle(fontSize: 13, height: 1.5)),
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
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
                final startDateTime = allDay
                    ? DateTime(eventDate.year, eventDate.month, eventDate.day)
                    : DateTime(
                        eventDate.year,
                        eventDate.month,
                        eventDate.day,
                        startTime.hour,
                        startTime.minute,
                      );
                final endDateTime = allDay
                    ? null
                    : DateTime(
                        eventDate.year,
                        eventDate.month,
                        eventDate.day,
                        endTime.hour,
                        endTime.minute,
                      );
                final featureLinkUrl = linkCtrl.text.trim();
                if (isEditing) {
                  final shouldUpdateFeatureLink =
                      initialFeatureLinkUrl.isNotEmpty ||
                      featureLinkUrl.isNotEmpty;
                  _updateEvent(
                    eventId: eventId,
                    title: title,
                    startAt: startDateTime,
                    endAt: endDateTime,
                    description: descCtrl.text.trim(),
                    allDay: allDay,
                    color: selectedColor,
                    featureLinkUrl: featureLinkUrl,
                    updateFeatureLink: shouldUpdateFeatureLink,
                  );
                } else {
                  _createEvent(
                    title: title,
                    startAt: startDateTime,
                    endAt: endDateTime,
                    description: descCtrl.text.trim(),
                    allDay: allDay,
                    color: selectedColor,
                    featureLinkUrl: featureLinkUrl,
                  );
                }
              },
              child: Text(isEditing ? '保存' : '追加'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventMetadataRow extends StatelessWidget {
  const _EventMetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(value, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _CalendarViewSwitcher extends StatelessWidget {
  const _CalendarViewSwitcher({
    required this.selectedView,
    required this.onChanged,
  });

  final _CalendarView selectedView;
  final ValueChanged<_CalendarView> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <(_CalendarView, String, IconData)>[
      (_CalendarView.month, 'Month', Icons.calendar_month),
      (_CalendarView.week, 'Week', Icons.view_week),
      (_CalendarView.day, 'Day', Icons.view_day),
    ];

    return Material(
      color: theme.colorScheme.surface,
      child: SizedBox(
        height: 56,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final item in items) ...[
                ChoiceChip(
                  avatar: Icon(item.$3, size: 18),
                  label: Text(item.$2),
                  selected: selectedView == item.$1,
                  onSelected: (_) => onChanged(item.$1),
                  showCheckmark: false,
                  selectedColor: theme.colorScheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: selectedView == item.$1
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DayViewHeader extends StatelessWidget {
  const _DayViewHeader({
    required this.selectedDay,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final DateTime selectedDay;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous day',
            icon: const Icon(Icons.chevron_left),
            onPressed: onPreviousDay,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${selectedDay.year}/${selectedDay.month}/${selectedDay.day}',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  'Day view',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            icon: const Icon(Icons.chevron_right),
            onPressed: onNextDay,
          ),
        ],
      ),
    );
  }
}

class _DayTimelineView extends StatelessWidget {
  const _DayTimelineView({
    required this.selectedDay,
    required this.events,
    required this.onTap,
    required this.onDetails,
    required this.onDelete,
  });

  static const double _hourHeight = 64;
  static const double _timeGutterWidth = 56;
  static const double _eventGap = 6;

  final DateTime selectedDay;
  final List<Map<String, dynamic>> events;
  final ValueChanged<Map<String, dynamic>> onTap;
  final ValueChanged<Map<String, dynamic>> onDetails;
  final ValueChanged<Map<String, dynamic>> onDelete;

  @override
  Widget build(BuildContext context) {
    final allDayEvents = events.where(_eventIsAllDay).toList();
    final entries = _buildTimelineEntries(events, selectedDay);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        if (allDayEvents.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final event in allDayEvents)
                InputChip(
                  avatar: CircleAvatar(
                    backgroundColor: _CalendarEventsPageState._eventColor(
                      event,
                    ).withValues(alpha: 0.18),
                    child: Icon(
                      Icons.event,
                      size: 16,
                      color: _CalendarEventsPageState._eventColor(event),
                    ),
                  ),
                  label: Text(_eventTitle(event)),
                  onPressed: () => onTap(event),
                  onDeleted: () => onDelete(event),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final contentWidth =
                constraints.maxWidth - _timeGutterWidth - (_eventGap * 2);
            final safeContentWidth = contentWidth < 0 ? 0.0 : contentWidth;

            return SizedBox(
              height: 24 * _hourHeight,
              child: Stack(
                children: [
                  for (var hour = 0; hour < 24; hour++)
                    Positioned(
                      top: hour * _hourHeight,
                      left: 0,
                      right: 0,
                      height: _hourHeight,
                      child: _HourSlot(hour: hour),
                    ),
                  for (final entry in entries)
                    _buildPositionedEvent(entry, safeContentWidth),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPositionedEvent(_TimelineEntry entry, double contentWidth) {
    final columnWidth =
        (contentWidth - (entry.columnCount - 1) * _eventGap) /
        entry.columnCount;
    final safeColumnWidth = columnWidth < 48 ? 48.0 : columnWidth;
    final top = (entry.startMinute / 60) * _hourHeight + 2;
    final height =
        ((entry.endMinute - entry.startMinute) / 60) * _hourHeight - 4;
    final safeHeight = height < 36 ? 36.0 : height;

    return Positioned(
      top: top,
      left:
          _timeGutterWidth +
          _eventGap +
          entry.column * (safeColumnWidth + _eventGap),
      width: safeColumnWidth,
      height: safeHeight,
      child: _DayTimelineEventTile(
        event: entry.event,
        color: _CalendarEventsPageState._eventColor(entry.event),
        onTap: () => onTap(entry.event),
        onLongPress: () => onDetails(entry.event),
        onDelete: () => onDelete(entry.event),
      ),
    );
  }

  List<_TimelineEntry> _buildTimelineEntries(
    List<Map<String, dynamic>> rawEvents,
    DateTime day,
  ) {
    final candidates = <_TimelineEntry>[];
    for (final event in rawEvents) {
      if (_eventIsAllDay(event)) continue;
      final range = _timelineRange(event, day);
      if (range == null) continue;
      candidates.add(
        _TimelineEntry(
          event: event,
          startMinute: range.startMinute,
          endMinute: range.endMinute,
        ),
      );
    }

    candidates.sort((a, b) {
      final byStart = a.startMinute.compareTo(b.startMinute);
      return byStart != 0 ? byStart : a.endMinute.compareTo(b.endMinute);
    });

    final entries = <_TimelineEntry>[];
    var group = <_TimelineEntry>[];
    var groupEnd = -1;

    void flushGroup() {
      if (group.isEmpty) return;
      final columns = <int>[];
      final laidOut = <_TimelineEntry>[];

      for (final candidate in group) {
        var column = columns.indexWhere(
          (endMinute) => endMinute <= candidate.startMinute,
        );
        if (column == -1) {
          column = columns.length;
          columns.add(candidate.endMinute);
        } else {
          columns[column] = candidate.endMinute;
        }
        laidOut.add(candidate.copyWith(column: column));
      }

      final columnCount = columns.length;
      entries.addAll(
        laidOut.map((entry) => entry.copyWith(columnCount: columnCount)),
      );
      group = <_TimelineEntry>[];
      groupEnd = -1;
    }

    for (final candidate in candidates) {
      if (group.isEmpty || candidate.startMinute < groupEnd) {
        group.add(candidate);
        if (candidate.endMinute > groupEnd) {
          groupEnd = candidate.endMinute;
        }
      } else {
        flushGroup();
        group.add(candidate);
        groupEnd = candidate.endMinute;
      }
    }
    flushGroup();

    return entries;
  }

  _TimelineRange? _timelineRange(Map<String, dynamic> event, DateTime day) {
    final start = _eventDateTime(event, 'start_at');
    if (start == null) return null;
    final end =
        _eventDateTime(event, 'end_at') ?? start.add(const Duration(hours: 1));

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    if (!end.isAfter(dayStart) || !start.isBefore(dayEnd)) return null;

    final clampedStart = start.isBefore(dayStart) ? dayStart : start;
    final clampedEnd = end.isAfter(dayEnd) ? dayEnd : end;
    final startMinute = _clampInt(
      clampedStart.difference(dayStart).inMinutes,
      0,
      1439,
    );
    final rawEndMinute = _clampInt(
      clampedEnd.difference(dayStart).inMinutes,
      1,
      1440,
    );
    final minimumEndMinute = _clampInt(startMinute + 30, 1, 1440);
    final endMinute = rawEndMinute < minimumEndMinute
        ? minimumEndMinute
        : rawEndMinute;

    return _TimelineRange(startMinute, endMinute);
  }
}

class _HourSlot extends StatelessWidget {
  const _HourSlot({required this.hour});

  final int hour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _DayTimelineView._timeGutterWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayTimelineEventTile extends StatelessWidget {
  const _DayTimelineEventTile({
    required this.event,
    required this.color,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final Map<String, dynamic> event;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = event['description']?.toString() ?? '';
    final hasFeatureLink = _eventFeatureLinkUrl(event) != null;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        onLongPress: onLongPress,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _eventTitle(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      Text(
                        _eventTimeLabel(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                if (hasFeatureLink)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 2),
                    child: Icon(
                      Icons.open_in_new,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                IconButton(
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineRange {
  const _TimelineRange(this.startMinute, this.endMinute);

  final int startMinute;
  final int endMinute;
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.event,
    required this.startMinute,
    required this.endMinute,
    this.column = 0,
    this.columnCount = 1,
  });

  final Map<String, dynamic> event;
  final int startMinute;
  final int endMinute;
  final int column;
  final int columnCount;

  _TimelineEntry copyWith({int? column, int? columnCount}) {
    return _TimelineEntry(
      event: event,
      startMinute: startMinute,
      endMinute: endMinute,
      column: column ?? this.column,
      columnCount: columnCount ?? this.columnCount,
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.color,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
  });

  final Map<String, dynamic> event;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = event['title']?.toString() ?? 'タイトルなし';
    final description = event['description']?.toString() ?? '';
    final startAt = event['start_at']?.toString() ?? '';
    final endAt = event['end_at']?.toString() ?? '';
    final allDay = event['all_day'] == true;
    final hasFeatureLink = _eventFeatureLinkUrl(event) != null;

    String fmt(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    String timeLabel = '';
    if (allDay) {
      timeLabel = '終日';
    } else if (startAt.isNotEmpty) {
      final start = DateTime.tryParse(startAt)?.toLocal();
      final end = DateTime.tryParse(endAt)?.toLocal();
      if (start != null && end != null) {
        timeLabel = '${fmt(start)} - ${fmt(end)}';
      } else if (start != null) {
        timeLabel = fmt(start);
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(Icons.event, color: color, size: 20),
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeLabel, style: const TextStyle(fontSize: 12, height: 1.5)),
            if (description.isNotEmpty)
              Text(
                description,
                style: const TextStyle(fontSize: 12, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasFeatureLink)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFE53935)),
              tooltip: '削除',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
