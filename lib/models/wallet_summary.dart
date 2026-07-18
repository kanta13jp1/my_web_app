/// デジタルウォレットの集計モデル。
///
/// `social-commerce-hub` Edge Function の `wallet.balance` レスポンスを
/// 解析する純データモデル (Flutter 依存なし → VM 単体テスト可能)。
///
/// EF レスポンス形状:
/// ```json
/// {
///   "success": true,
///   "balance": 1500,
///   "currency": "JPY",
///   "transactions": [
///     {
///       "id": "...",
///       "metadata": {
///         "amount": 2000,        // 入金は正 / 支払いは負
///         "type": "deposit",     // deposit | payment
///         "method": "card",      // 入金の資金源
///         "currency": "JPY",
///         "user_id": "..."
///       },
///       "created_at": "2026-07-12T..."   // トップレベル列
///     }
///   ]
/// }
/// ```
///
/// 旧実装は `tx['amount']` / `tx['type']` / `tx['description']` という
/// 存在しない flat キーを読んでいたため、全取引行が
/// 「取引 N / ¥0 / 支出(赤)」という捏造表示になり、
/// さらに `balance` は取得しても一切表示されていなかった。
/// 本モデルは nested `metadata` から正しく読み取り、金額の符号で
/// 入出金を判定する。
library;

num _toNum(dynamic value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? 0;
}

/// ウォレット取引 1 件。
class WalletTransaction {
  const WalletTransaction({
    required this.amount,
    required this.type,
    required this.note,
    required this.createdAt,
  });

  /// 符号付き金額 (JPY)。正 = 入金 / 負 = 支払い。
  final num amount;

  /// 取引種別。`deposit` / `payment` など。空文字の場合あり。
  final String type;

  /// 補足 (`reason` / 入金の `method` / 支払いの `to`)。空文字の場合あり。
  final String note;

  /// 生の ISO タイムスタンプ (空文字の場合あり)。
  final String createdAt;

  /// 入金 (money in) なら true、支払い (money out) なら false。
  /// 通常は金額の符号で判定し、0 円だけは `type` で補完する。
  bool get isCredit {
    if (amount > 0) return true;
    if (amount < 0) return false;
    return type != 'payment';
  }

  /// 人が読める表示ラベル ('入金・card' / '支払い・alice' 等)。
  String get label {
    final base = _typeLabel();
    return note.isEmpty ? base : '$base・$note';
  }

  String _typeLabel() {
    switch (type) {
      case 'deposit':
        return '入金';
      case 'payment':
        return '支払い';
      default:
        // 種別不明時は符号で補完する。
        return isCredit ? '入金' : '支払い';
    }
  }

  /// EF の hub_data 行 (nested metadata) から 1 件を構築する。
  /// 後方互換のため flat キーもフォールバックとして読む。
  factory WalletTransaction.fromMap(Map<String, dynamic> raw) {
    final metadata = raw['metadata'];
    final meta = metadata is Map
        ? metadata.cast<String, dynamic>()
        : const <String, dynamic>{};

    final rawAmount = meta['amount'] ?? raw['amount'] ?? 0;
    final type = (meta['type'] ?? raw['type'] ?? '').toString().trim();
    final note = (meta['reason'] ??
            meta['method'] ??
            meta['to'] ??
            raw['reason'] ??
            raw['method'] ??
            raw['to'] ??
            '')
        .toString()
        .trim();
    final createdAt =
        (raw['created_at'] ?? meta['created_at'] ?? '').toString();

    return WalletTransaction(
      amount: _toNum(rawAmount),
      type: type,
      note: note,
      createdAt: createdAt,
    );
  }
}

/// 残高 + 取引履歴のまとめ。
class WalletSummary {
  const WalletSummary({required this.balance, required this.transactions});

  /// 合計残高 (JPY)。
  final num balance;

  /// 取引履歴 (新しい順)。
  final List<WalletTransaction> transactions;

  bool get isEmpty => transactions.isEmpty;

  static const WalletSummary empty =
      WalletSummary(balance: 0, transactions: <WalletTransaction>[]);

  /// EF レスポンス (`{balance, transactions}` / 生の List / null) を頑健に解析する。
  factory WalletSummary.fromResponse(dynamic data) {
    List<Map<String, dynamic>> rawList;
    num? balance;

    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final txns = map['transactions'];
      rawList = txns is List
          ? txns.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : <Map<String, dynamic>>[];
      // balance:0 は正当な残高なので「キー存在」で判定する (null のみ未取得扱い)。
      if (map['balance'] != null) balance = _toNum(map['balance']);
    } else if (data is List) {
      rawList =
          data.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else {
      rawList = <Map<String, dynamic>>[];
    }

    final transactions = rawList.map(WalletTransaction.fromMap).toList();
    // EF が balance を省略した場合 (生 List 等) のみ履歴から算出する。
    balance ??= transactions.fold<num>(0, (sum, t) => sum + t.amount);

    return WalletSummary(balance: balance, transactions: transactions);
  }
}

/// 金額を桁区切り付きの円表示に整形する ('1,500' 等)。
/// 整数は小数点なし、非整数は小数第 2 位まで。負号は呼び出し側で付ける想定。
String formatWalletYen(num value) {
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
String formatWalletTimestamp(String raw) {
  if (raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
