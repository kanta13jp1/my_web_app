/// 在庫アイテムのモデル。
///
/// `social-commerce-hub` Edge Function の `inventory.list` レスポンスを
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
///         "name": "USB ケーブル",
///         "sku": "USB-001",
///         "quantity": 12,
///         "price": 500,
///         "category": "周辺機器",
///         "location": "A-1",
///         "user_id": "..."
///       },
///       "created_at": "2026-07-12T..."   // トップレベル列
///     }
///   ]
/// }
/// ```
///
/// 旧実装は `item['name']` / `item['sku']` / `item['quantity']` を flat キーで
/// 読み (実体は `metadata.*`)、さらに EF に存在しない `item['minQuantity']` を
/// 読んでいた。結果 quantity=0・min=0 となり `0 <= 0` で **全品「在庫不足」の
/// 赤バナー**が出ていた。本モデルは nested `metadata` を読み、しきい値が
/// 実在しない限り在庫不足を捏造しない。
library;

num _toNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

num? _toNumOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

/// 在庫アイテム 1 件。
class InventoryItemSummary {
  const InventoryItemSummary({
    required this.name,
    required this.sku,
    required this.quantity,
    required this.minQuantity,
    required this.price,
    required this.category,
    required this.location,
    required this.createdAt,
  });

  /// 品名。
  final String name;

  /// SKU (空文字の場合あり)。
  final String sku;

  /// 在庫数。
  final num quantity;

  /// 発注点 (再発注しきい値)。EF に無ければ 0。
  final num minQuantity;

  /// 単価 (JPY)。未設定なら null。
  final num? price;

  /// カテゴリ (空文字の場合あり)。
  final String category;

  /// 保管場所 (空文字の場合あり)。
  final String location;

  /// 生の ISO タイムスタンプ (空文字の場合あり)。
  final String createdAt;

  /// 在庫切れ (0 以下)。
  bool get isOutOfStock => quantity <= 0;

  /// 在庫不足。**発注点が実在 (>0) するときのみ**判定する。
  /// しきい値が無ければ捏造しない (旧バグ回避)。
  bool get isLowStock => minQuantity > 0 && quantity <= minQuantity;

  /// EF の hub_data 行 (nested metadata) から 1 件を構築する。
  /// 後方互換のため flat キーもフォールバックとして読む。
  factory InventoryItemSummary.fromMap(Map<String, dynamic> raw) {
    final metadata = raw['metadata'];
    final meta = metadata is Map
        ? metadata.cast<String, dynamic>()
        : const <String, dynamic>{};

    String str(String key, [String alt = '']) =>
        (meta[key] ?? raw[key] ?? alt).toString().trim();

    return InventoryItemSummary(
      name: (meta['name'] ?? raw['name'] ?? '').toString().trim(),
      sku: str('sku'),
      quantity: _toNum(meta['quantity'] ?? raw['quantity'] ?? 0),
      minQuantity: _toNum(
        meta['minQuantity'] ??
            meta['min_quantity'] ??
            meta['reorder_point'] ??
            raw['minQuantity'] ??
            0,
      ),
      price: _toNumOrNull(meta['price'] ?? raw['price']),
      category: str('category'),
      location: str('location'),
      createdAt: (raw['created_at'] ?? meta['created_at'] ?? '').toString(),
    );
  }
}

/// EF レスポンス (`{items}` / 生の List / null) を頑健に解析する。
List<InventoryItemSummary> parseInventoryItems(dynamic data) {
  List<Map<String, dynamic>> rawList;
  if (data is Map) {
    final map = data.cast<String, dynamic>();
    final list = map['items'];
    rawList = list is List
        ? list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
  } else if (data is List) {
    rawList =
        data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  } else {
    rawList = <Map<String, dynamic>>[];
  }
  return rawList.map(InventoryItemSummary.fromMap).toList();
}
