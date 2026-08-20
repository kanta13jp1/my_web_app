/// ギフトレジストリのアイテムモデル。
///
/// `social-commerce-hub` Edge Function の `gift.list` レスポンスを
/// 解析する純データモデル (Flutter 依存なし → VM 単体テスト可能)。
///
/// EF レスポンス形状:
/// ```json
/// {
///   "success": true,
///   "items": [
///     {
///       "id": "...",
///       "metadata": {
///         "name": "コーヒーメーカー",
///         "url": "https://...",
///         "price": 8000,
///         "priority": "high",
///         "purchased": false,
///         "user_id": "..."
///       },
///       "created_at": "2026-07-12T..."   // トップレベル列
///     }
///   ]
/// }
/// ```
///
/// 旧実装は `gift['name']` / `gift['price']` / `gift['reserved']` という
/// flat キーを読んでいたが、これらは nested `metadata` 配下にあるため、
/// 全アイテムが「ギフト N・価格非表示・予約済バッジ消失」という
/// 捏造表示になっていた (`purchased` を `reserved` と誤読)。
/// 本モデルは nested `metadata` から正しく読み取る。
library;

num? _toNumOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

/// ギフト 1 件。
class GiftRegistryItem {
  const GiftRegistryItem({
    required this.name,
    required this.url,
    required this.price,
    required this.priority,
    required this.purchased,
    required this.createdAt,
  });

  /// 品名。
  final String name;

  /// 商品 URL (空文字の場合あり)。
  final String url;

  /// 価格 (JPY)。未設定なら null。
  final num? price;

  /// 優先度 ('high' / 'medium' / 'low')。
  final String priority;

  /// 購入 (予約) 済みなら true。
  final bool purchased;

  /// 生の ISO タイムスタンプ (空文字の場合あり)。
  final String createdAt;

  bool get hasPrice => price != null;

  /// EF の hub_data 行 (nested metadata) から 1 件を構築する。
  /// 後方互換のため flat キーもフォールバックとして読む。
  factory GiftRegistryItem.fromMap(Map<String, dynamic> raw) {
    final metadata = raw['metadata'];
    final meta = metadata is Map
        ? metadata.cast<String, dynamic>()
        : const <String, dynamic>{};

    final name =
        (meta['name'] ?? meta['title'] ?? raw['name'] ?? raw['title'] ?? '')
            .toString()
            .trim();
    final url = (meta['url'] ?? raw['url'] ?? '').toString().trim();
    final price = _toNumOrNull(meta['price'] ?? raw['price'] ?? raw['amount']);
    final priority =
        (meta['priority'] ?? raw['priority'] ?? 'medium').toString().trim();
    // EF は `purchased` を使う。旧 UI の `reserved` も後方互換で読む。
    final purchased = (meta['purchased'] ?? raw['purchased'] ?? raw['reserved'])
            ?.toString() ==
        'true';
    final createdAt =
        (raw['created_at'] ?? meta['created_at'] ?? '').toString();

    return GiftRegistryItem(
      name: name,
      url: url,
      price: price,
      priority: priority.isEmpty ? 'medium' : priority,
      purchased: purchased,
      createdAt: createdAt,
    );
  }
}

/// EF レスポンス (`{items|gifts}` / 生の List / null) を頑健に解析する。
List<GiftRegistryItem> parseGiftRegistryItems(dynamic data) {
  List<Map<String, dynamic>> rawList;
  if (data is Map) {
    final map = data.cast<String, dynamic>();
    final list = map['gifts'] ?? map['items'];
    rawList = list is List
        ? list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
  } else if (data is List) {
    rawList =
        data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  } else {
    rawList = <Map<String, dynamic>>[];
  }
  return rawList.map(GiftRegistryItem.fromMap).toList();
}

/// 価格を桁区切り付きの円表示に整形する ('8,000' 等)。
String formatGiftPrice(num value) {
  final digits = value.round().toString();
  final buffer = StringBuffer();
  final len = digits.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
