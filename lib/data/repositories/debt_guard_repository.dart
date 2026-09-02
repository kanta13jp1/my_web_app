import '../../domain/models/debt_guard_rule.dart';
import '../services/debt_guard_event_service.dart';

abstract interface class DebtGuardRepository {
  Future<List<DebtGuardEvent>> loadDailyEvents({
    required String userId,
    required DateTime date,
  });

  Future<List<DebtGuardEvent>> appendEvents({
    required String userId,
    required DateTime date,
    required List<DebtGuardEventDraft> events,
  });
}

class DebtGuardEventDraft {
  const DebtGuardEventDraft({
    required this.ruleId,
    required this.type,
    this.note,
  });

  final String ruleId;
  final DebtGuardEventType type;
  final String? note;
}

class SupabaseDebtGuardRepository implements DebtGuardRepository {
  const SupabaseDebtGuardRepository({required DebtGuardEventService service})
      : _service = service;

  final DebtGuardEventService _service;

  @override
  Future<List<DebtGuardEvent>> loadDailyEvents({
    required String userId,
    required DateTime date,
  }) async {
    final rows = await _service.loadDailyEvents(
      userId: userId,
      eventDate: _dateKey(date),
    );
    return _parseAndSort(rows);
  }

  @override
  Future<List<DebtGuardEvent>> appendEvents({
    required String userId,
    required DateTime date,
    required List<DebtGuardEventDraft> events,
  }) async {
    final eventDate = _dateKey(date);
    final rows = await _service.appendEvents([
      for (final event in events)
        <String, dynamic>{
          'user_id': userId,
          'rule_id': event.ruleId,
          'event_type': event.type.wireName,
          'event_date': eventDate,
          if (event.note?.trim().isNotEmpty == true) 'note': event.note!.trim(),
        },
    ]);
    return _parseAndSort(rows);
  }

  static List<DebtGuardEvent> _parseAndSort(List<Map<String, dynamic>> rows) {
    final events = rows.map(_parse).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return events;
  }

  static DebtGuardEvent _parse(Map<String, dynamic> row) {
    return DebtGuardEvent(
      id: (row['id'] as num).toInt(),
      ruleId: row['rule_id'] as String,
      type: DebtGuardEventTypeCopy.fromWireName(row['event_type'] as String),
      eventDate: DateTime.parse(row['event_date'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      note: row['note'] as String?,
    );
  }

  static String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }
}
