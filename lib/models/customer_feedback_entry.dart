/// カスタマーフィードバックのエントリモデル。
///
/// `social-commerce-hub` Edge Function の `feedback.list` レスポンスを
/// 解析する純データモデル (Flutter 依存なし → VM 単体テスト可能)。
///
/// EF レスポンス形状:
/// ```json
/// {
///   "success": true,
///   "feedbacks": [
///     {
///       "id": "...",
///       "metadata": {
///         "type": "general",
///         "rating": 4,
///         "comment": "とても使いやすい",
///         "feature": "dashboard",
///         "status": "open",
///         "user_id": "..."
///       },
///       "created_at": "2026-07-12T..."   // トップレベル列
///     }
///   ]
/// }
/// ```
///
/// 旧実装は `item['feedback']` / `item['text']` / `item['content']` を読み、
/// いずれも存在しないため `item.toString()` にフォールバックしていた。
/// 結果、**行 Map 全体** (`{id: ..., metadata: {...}}`) がそのまま
/// 見出しに描画されていた。本モデルは nested `metadata.comment` を読む。
library;

num? _toNumOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

/// フィードバック 1 件。
class CustomerFeedbackEntry {
  const CustomerFeedbackEntry({
    required this.comment,
    required this.type,
    required this.rating,
    required this.feature,
    required this.status,
    required this.createdAt,
  });

  /// 本文コメント。
  final String comment;

  /// 種別 ('general' / 'bug' / 'feature' 等)。空文字の場合あり。
  final String type;

  /// 評価 (1-5 等)。未設定なら null。
  final num? rating;

  /// 対象機能。空文字の場合あり。
  final String feature;

  /// ステータス ('open' 等)。空文字の場合あり。
  final String status;

  /// 生の ISO タイムスタンプ (空文字の場合あり)。
  final String createdAt;

  /// 表示用テキスト。コメントが空なら明示的なプレースホルダを返す
  /// (旧実装のように行 Map 全体を描画しない)。
  String get displayText => comment.isEmpty ? '(コメントなし)' : comment;

  /// EF の hub_data 行 (nested metadata) から 1 件を構築する。
  /// 後方互換のため flat キーもフォールバックとして読む。
  factory CustomerFeedbackEntry.fromMap(Map<String, dynamic> raw) {
    final metadata = raw['metadata'];
    final meta = metadata is Map
        ? metadata.cast<String, dynamic>()
        : const <String, dynamic>{};

    String pick(List<String> keys) {
      for (final k in keys) {
        final v = meta[k] ?? raw[k];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return '';
    }

    return CustomerFeedbackEntry(
      comment: pick(['comment', 'feedback', 'text', 'content', 'message']),
      type: pick(['type']),
      rating: _toNumOrNull(meta['rating'] ?? raw['rating']),
      feature: pick(['feature']),
      status: pick(['status']),
      createdAt: (raw['created_at'] ?? meta['created_at'] ?? '').toString(),
    );
  }
}

/// EF レスポンス (`{feedbacks|items}` / 生の List / null) を頑健に解析する。
List<CustomerFeedbackEntry> parseCustomerFeedback(dynamic data) {
  List<Map<String, dynamic>> rawList;
  if (data is Map) {
    final map = data.cast<String, dynamic>();
    final list = map['feedbacks'] ?? map['items'];
    rawList = list is List
        ? list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
  } else if (data is List) {
    rawList =
        data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  } else {
    rawList = <Map<String, dynamic>>[];
  }
  return rawList.map(CustomerFeedbackEntry.fromMap).toList();
}
