import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'asset_payment_calendar_service.dart';

/// Debt Guard (`prison_rule_events`) の「追加の借金 (`additional_borrowing`)」
/// 違反ログをカレンダー向けに読み書きするサービス。
class AssetDebtGuardCalendarService {
  const AssetDebtGuardCalendarService._();

  static const String additionalBorrowingRuleId = 'additional_borrowing';
  static const String violationEventType = 'violation';
  static const int maxNoteLength = 500;

  static String formatDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static DateTime? _parseStrictDate(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  /// `prison_rule_events` 行リストから有効な `additional_borrowing` 違反のみ抽出する。
  static List<AssetCalendarDebtGuardViolationInput> parseRows(dynamic rowsRaw) {
    final rows = rowsRaw is List ? rowsRaw : const <dynamic>[];
    final results = <AssetCalendarDebtGuardViolationInput>[];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final ruleId = row['rule_id']?.toString().trim();
      final eventType = row['event_type']?.toString().trim();
      if (ruleId != null &&
          ruleId.isNotEmpty &&
          ruleId != additionalBorrowingRuleId) {
        continue;
      }
      if (eventType != null &&
          eventType.isNotEmpty &&
          eventType != violationEventType) {
        continue;
      }
      final date = _parseStrictDate(row['event_date']?.toString());
      if (date == null) continue;
      final note = row['note']?.toString().trim() ?? '';
      results.add(
        AssetCalendarDebtGuardViolationInput(
          date: date,
          note: note,
          sourceId: row['id']?.toString(),
        ),
      );
    }
    return results;
  }

  static Future<List<AssetCalendarDebtGuardViolationInput>>
      loadBorrowingViolations({
    required SupabaseClient client,
    required String userId,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    try {
      final rows = await client
          .from('prison_rule_events')
          .select('id, rule_id, event_type, note, event_date')
          .eq('user_id', userId)
          .eq('rule_id', additionalBorrowingRuleId)
          .eq('event_type', violationEventType)
          .gte('event_date', formatDateKey(start))
          .lt('event_date', formatDateKey(endExclusive))
          .order('event_date', ascending: true);
      return parseRows(rows);
    } catch (e) {
      debugPrint('AssetDebtGuardCalendarService.loadBorrowingViolations: $e');
      return const <AssetCalendarDebtGuardViolationInput>[];
    }
  }

  static Future<AssetCalendarDebtGuardViolationInput?> recordViolation({
    required SupabaseClient client,
    required String userId,
    required DateTime eventDate,
    String? note,
  }) async {
    final trimmed = note?.trim() ?? '';
    final normalizedNote = trimmed.isEmpty
        ? null
        : (trimmed.length > maxNoteLength
            ? trimmed.substring(0, maxNoteLength)
            : trimmed);
    final dateKey = formatDateKey(eventDate);
    final inserted = await client
        .from('prison_rule_events')
        .insert(<String, dynamic>{
          'user_id': userId,
          'rule_id': additionalBorrowingRuleId,
          'event_type': violationEventType,
          'event_date': dateKey,
          'note': normalizedNote,
        })
        .select('id, rule_id, event_type, note, event_date')
        .maybeSingle();
    if (inserted != null) {
      final parsed = parseRows(<dynamic>[inserted]);
      if (parsed.isNotEmpty) {
        return parsed.first;
      }
    }
    return AssetCalendarDebtGuardViolationInput(
      date: DateTime(eventDate.year, eventDate.month, eventDate.day),
      note: normalizedNote ?? '',
    );
  }
}
