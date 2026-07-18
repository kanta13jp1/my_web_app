/// ロイヤリティポイントの集計モデル。
///
/// `social-commerce-hub` Edge Function の `loyalty.balance` レスポンスを
/// 解析する純データモデル (Flutter 依存なし → VM 単体テスト可能)。
///
/// EF レスポンス形状:
/// ```json
/// {
///   "success": true,
///   "balance": 1250,
///   "history": [
///     {
///       "id": "...",
///       "metadata": {
///         "amount": 500,          // 付与は正 / 交換は負
///         "reason": "初回登録ボーナス",
///         "earned_at": "2026-07-12T...",
///         "user_id": "..."
///       },
///       "created_at": "2026-07-12T..."   // トップレベル列
///     }
///   ]
/// }
/// ```
///
/// 旧実装は `item['points']` / `item['type']` / `item['description']` という
/// 存在しないキーを読んでいたため、全行が「ポイント N / +0 pt」という
/// 捏造表示になっていた。本モデルは nested `metadata` から正しく読み取る。
library;

num _toNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

/// ポイント履歴 1 件。
class LoyaltyPointEntry {
  const LoyaltyPointEntry({
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  /// 符号付きポイント数。正 = 付与 / 負 = 交換 (redeem)。
  final num amount;

  /// 人が読める理由・説明。
  final String reason;

  /// 生の ISO タイムスタンプ (空文字の場合あり)。
  final String createdAt;

  /// 付与 (earn) なら true、交換 (redeem) なら false。
  bool get isEarn => amount >= 0;

  /// EF の hub_data 行 (nested metadata) から 1 件を構築する。
  /// 後方互換のため flat キーもフォールバックとして読む。
  factory LoyaltyPointEntry.fromMap(Map<String, dynamic> raw) {
    final metadata = raw['metadata'];
    final meta = metadata is Map
        ? metadata.cast<String, dynamic>()
        : const <String, dynamic>{};

    final rawAmount = meta['amount'] ?? raw['amount'] ?? raw['points'] ?? 0;
    final reason = (meta['reason'] ?? raw['reason'] ?? raw['description'] ?? '')
        .toString()
        .trim();
    final createdAt =
        (raw['created_at'] ?? meta['earned_at'] ?? meta['redeemed_at'] ?? '')
            .toString();

    return LoyaltyPointEntry(
      amount: _toNum(rawAmount),
      reason: reason.isEmpty ? 'ポイント履歴' : reason,
      createdAt: createdAt,
    );
  }
}

/// ポイント残高 + 履歴のまとめ。
class LoyaltyPointsSummary {
  const LoyaltyPointsSummary({required this.balance, required this.entries});

  /// 合計ポイント残高。
  final num balance;

  /// 履歴 (新しい順)。
  final List<LoyaltyPointEntry> entries;

  bool get isEmpty => entries.isEmpty;

  static const LoyaltyPointsSummary empty =
      LoyaltyPointsSummary(balance: 0, entries: <LoyaltyPointEntry>[]);

  /// EF レスポンス (`{balance, history}` / 生の List / null) を頑健に解析する。
  factory LoyaltyPointsSummary.fromResponse(dynamic data) {
    List<Map<String, dynamic>> rawList;
    num? balance;

    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final history = map['history'];
      rawList = history is List
          ? history
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
          : <Map<String, dynamic>>[];
      // balance:0 は正当な値なので「キー存在」で判定する (null のみ未取得扱い)。
      if (map['balance'] != null) balance = _toNum(map['balance']);
    } else if (data is List) {
      rawList =
          data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else {
      rawList = <Map<String, dynamic>>[];
    }

    final entries = rawList.map(LoyaltyPointEntry.fromMap).toList();
    // EF が balance を省略した場合 (生 List 等) のみ履歴から算出する。
    balance ??= entries.fold<num>(0, (sum, e) => sum + e.amount);

    return LoyaltyPointsSummary(balance: balance, entries: entries);
  }
}

/// ポイント数を桁区切り付きで表示用に整形する ('1,250' 等)。
/// 整数は小数点なし、非整数は小数第 2 位まで。
String formatLoyaltyPoints(num value) {
  final isNegative = value < 0;
  final abs = value.abs();
  final body = abs == abs.roundToDouble()
      ? _addThousands(abs.round().toString())
      : abs.toStringAsFixed(2);
  return '${isNegative ? '-' : ''}$body';
}

String _addThousands(String digits) {
  final buffer = StringBuffer();
  final len = digits.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// ISO タイムスタンプを 'yyyy/MM/dd HH:mm' (ローカル) に整形する。
/// パース不能なら生文字列をそのまま返す。
String formatLoyaltyTimestamp(String raw) {
  if (raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
