/// hub_data 行 (social-commerce-hub / lifestyle-hub) 共通パースヘルパー。
///
/// 両 EF の list 系 action は各レコードを
/// `{id, created_at, metadata: {...実フィールド}}` で返す (トップレベルは
/// `id` / `created_at` のみ)。UI が flat キー `row['field']` を読むと全行が
/// フォールバック値に化ける contract バグの温床なので、モデルは必ず
/// ここを経由して nested `metadata` から読む (flat キーは後方互換)。
///
/// 純 Dart (Flutter 依存なし) → VM 単体テスト可能。
/// 修正正本パターン: [loyalty_points_summary.dart] (PR #3948) 参照。
library;

/// hub_data 行から nested `metadata` を取り出す (無ければ空 Map)。
Map<String, dynamic> hubMetadataOf(Map<String, dynamic> raw) {
  final metadata = raw['metadata'];
  return metadata is Map
      ? metadata.cast<String, dynamic>()
      : const <String, dynamic>{};
}

/// `metadata[key]` 優先・flat `raw[key]` フォールバックで値を読む。
dynamic hubField(Map<String, dynamic> raw, String key) {
  final meta = hubMetadataOf(raw);
  return meta[key] ?? raw[key];
}

/// 数値化 (num / 数値文字列以外は fallback)。
num hubNum(dynamic value, [num fallback = 0]) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? fallback;
}

/// 文字列化 + trim (null は空文字)。
String hubString(dynamic value) => (value ?? '').toString().trim();

/// EF レスポンスから hub_data 行リストを取り出す。
/// `{success, <listKey>: [...]}` 形式 / 生 List / null を頑健に処理する。
List<Map<String, dynamic>> hubRowsFromResponse(dynamic data, String listKey) {
  final dynamic rawList = data is Map ? data[listKey] : data;
  if (rawList is! List) return const <Map<String, dynamic>>[];
  return rawList
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .toList();
}

/// ISO タイムスタンプを 'yyyy/MM/dd HH:mm' (ローカル) に整形する。
/// パース不能なら生文字列をそのまま返す (捏造しない)。
String hubFormatTimestamp(String raw) {
  if (raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
