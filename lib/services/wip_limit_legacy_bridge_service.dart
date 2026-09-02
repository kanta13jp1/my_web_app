import 'package:supabase_flutter/supabase_flutter.dart';

class LegacyWipItem {
  const LegacyWipItem({
    required this.id,
    required this.category,
    required this.emoji,
    required this.title,
    required this.note,
    required this.progressPercent,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String emoji;
  final String title;
  final String note;
  final int progressPercent;
  final String status;
  final DateTime? createdAt;

  bool get isCompleted => status == 'completed';
}

class LegacyWipLoadResult {
  const LegacyWipLoadResult({required this.items, this.warning});

  final List<LegacyWipItem> items;
  final String? warning;
}

/// 統合前の `/wip-limit` が保存した `wip_items` を、正規の消化キューで
/// 引き続き確認・更新するための読み書きブリッジ。
class WipLimitLegacyBridgeService {
  WipLimitLegacyBridgeService({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  Future<LegacyWipLoadResult> load() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const LegacyWipLoadResult(items: <LegacyWipItem>[]);
    }

    try {
      final rows = await _client
          .from('wip_items')
          .select(
            'id,category,emoji,title,note,progress_percent,status,created_at',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return LegacyWipLoadResult(items: parseRows(rows));
    } catch (error) {
      return LegacyWipLoadResult(
        items: const <LegacyWipItem>[],
        warning: '旧WIP項目を読み込めませんでした: $error',
      );
    }
  }

  Future<void> updateProgress(String itemId, int progressPercent) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('ログインが必要です');
    final normalized = progressPercent.clamp(0, 100);
    final completed = normalized == 100;
    await _client
        .from('wip_items')
        .update(<String, dynamic>{
          'progress_percent': normalized,
          'status': completed ? 'completed' : 'active',
          'completed_at': completed ? DateTime.now().toIso8601String() : null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itemId)
        .eq('user_id', userId);
  }

  static List<LegacyWipItem> parseRows(Object? value) {
    if (value is! List) return const <LegacyWipItem>[];
    return value.whereType<Map>().map((raw) {
      final row = Map<String, dynamic>.from(raw);
      return LegacyWipItem(
        id: _text(row['id']),
        category: _text(row['category'], fallback: 'その他'),
        emoji: _text(row['emoji'], fallback: '📦'),
        title: _text(row['title'], fallback: '名称未設定'),
        note: _text(row['note']),
        progressPercent: _progress(row['progress_percent']),
        status: _text(row['status'], fallback: 'active'),
        createdAt: DateTime.tryParse(_text(row['created_at'])),
      );
    }).toList(growable: false);
  }

  static int _progress(Object? value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return parsed.clamp(0, 100);
  }

  static String _text(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }
}
