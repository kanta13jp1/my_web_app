import 'package:supabase_flutter/supabase_flutter.dart';

enum ViralAdLegacyHistorySource { videoAd, viralVideo }

class ViralAdLegacyHistoryEntry {
  const ViralAdLegacyHistoryEntry({
    required this.id,
    required this.source,
    required this.title,
    required this.detail,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final ViralAdLegacyHistorySource source;
  final String title;
  final String detail;
  final String status;
  final DateTime? createdAt;

  String get sourceLabel => switch (source) {
        ViralAdLegacyHistorySource.videoAd => '旧 動画広告',
        ViralAdLegacyHistorySource.viralVideo => '旧 バイラル動画',
      };
}

class ViralAdLegacyHistoryLoadResult {
  const ViralAdLegacyHistoryLoadResult({
    required this.entries,
    required this.warnings,
  });

  final List<ViralAdLegacyHistoryEntry> entries;
  final List<String> warnings;
}

/// 統合前の動画広告・バイラル動画入口で保存された `hub_data` を、
/// 正規のバイラル広告画面から引き続き参照できる形へ変換する。
class ViralAdLegacyHistoryService {
  ViralAdLegacyHistoryService({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  Future<ViralAdLegacyHistoryLoadResult> load() async {
    final entries = <ViralAdLegacyHistoryEntry>[];
    final warnings = <String>[];

    try {
      final response = await _client.functions.invoke(
        'growth-hub',
        body: const <String, dynamic>{'action': 'video_ad.list'},
      );
      entries.addAll(parseVideoAdResponse(response.data));
    } catch (error) {
      warnings.add('旧動画広告履歴を読み込めませんでした: $error');
    }

    try {
      final response = await _client.functions.invoke(
        'media-hub',
        body: const <String, dynamic>{'action': 'viral_video.list_briefs'},
      );
      entries.addAll(parseViralVideoResponse(response.data));
    } catch (error) {
      warnings.add('旧バイラル動画履歴を読み込めませんでした: $error');
    }

    entries.sort((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return ViralAdLegacyHistoryLoadResult(
      entries: List.unmodifiable(entries),
      warnings: List.unmodifiable(warnings),
    );
  }

  static List<ViralAdLegacyHistoryEntry> parseVideoAdResponse(Object? data) {
    return _rows(data, 'items').map((row) {
      final metadata = _map(row['metadata']);
      return ViralAdLegacyHistoryEntry(
        id: _text(row['id']),
        source: ViralAdLegacyHistorySource.videoAd,
        title: _firstText(
          <Object?>[metadata['title']],
          fallback: '動画広告',
        ),
        detail: _firstText(
          <Object?>[
            metadata['platform'],
            metadata['style'],
            metadata['script'],
          ],
          fallback: '広告ブリーフ',
        ),
        status: _firstText(
          <Object?>[metadata['status']],
          fallback: 'draft',
        ),
        createdAt: DateTime.tryParse(_text(row['created_at'])),
      );
    }).toList(growable: false);
  }

  static List<ViralAdLegacyHistoryEntry> parseViralVideoResponse(Object? data) {
    return _rows(data, 'briefs').map((row) {
      final metadata = _map(row['metadata']);
      return ViralAdLegacyHistoryEntry(
        id: _text(row['id']),
        source: ViralAdLegacyHistorySource.viralVideo,
        title: _firstText(
          <Object?>[
            metadata['topic'],
            metadata['productSummary'],
          ],
          fallback: 'バイラル動画ブリーフ',
        ),
        detail: _firstText(
          <Object?>[
            metadata['style'],
            metadata['adStyle'],
            metadata['script'],
          ],
          fallback: 'SNS動画企画',
        ),
        status: _firstText(
          <Object?>[metadata['status']],
          fallback: 'draft',
        ),
        createdAt: DateTime.tryParse(_text(row['created_at'])),
      );
    }).toList(growable: false);
  }

  static List<Map<String, dynamic>> _rows(Object? data, String key) {
    final value = _map(data)[key];
    if (value is! List) return const <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  static String _firstText(List<Object?> values, {required String fallback}) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return fallback;
  }

  static String _text(Object? value) => value?.toString().trim() ?? '';
}
