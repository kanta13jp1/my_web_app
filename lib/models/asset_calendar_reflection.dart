enum AssetReflectionKind { dining, drinkingOut, alcoholPurchase, reading }

extension AssetReflectionKindLabel on AssetReflectionKind {
  String get label => switch (this) {
    AssetReflectionKind.dining => '外食',
    AssetReflectionKind.drinkingOut => '外飲み',
    AssetReflectionKind.alcoholPurchase => '酒購入',
    AssetReflectionKind.reading => '読書',
  };
}

/// Nonfinancial observations: never an input to balance or cashflow totals.
class AssetCalendarReflection {
  const AssetCalendarReflection({
    required this.sourceKey, required this.date, required this.kinds,
    required this.title, required this.sourceLabel, this.memo = '',
    this.verifiedAmount, this.alcoholAmount, this.pages, this.minutes,
    this.linkedFlowId,
  });
  final String sourceKey;
  final DateTime date;
  final Set<AssetReflectionKind> kinds;
  final String title;
  final String sourceLabel;
  final String memo;
  final double? verifiedAmount;
  final double? alcoholAmount;
  final int? pages;
  final int? minutes;
  final String? linkedFlowId;

  factory AssetCalendarReflection.fromJson(Map<String, dynamic> json) {
    String requiredText(String key, int max) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty || value.length > max) {
        throw FormatException('$key を確認してください');
      }
      return value.trim();
    }
    double? amount(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num || !value.isFinite || value < 0 || value > 100000000) {
        throw FormatException('$key は確認済みの金額か null にしてください');
      }
      return value.toDouble();
    }
    int? count(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! int || value < 0 || value > 1000000) throw FormatException('$key を確認してください');
      return value;
    }
    final day = requiredText('occurred_on', 10);
    final date = DateTime.tryParse(day);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) || date == null ||
        date.toIso8601String().substring(0, 10) != day) {
      throw const FormatException('日付は実在する年月日にしてください');
    }
    final values = json['kinds'];
    if (values is! List || values.isEmpty) throw const FormatException('種類が必要です');
    final kinds = values.map((value) => AssetReflectionKind.values.firstWhere(
      (kind) => kind.name == value, orElse: () => throw const FormatException('未対応の種類です'),
    )).toSet();
    final pages = count('pages'); final minutes = count('minutes');
    if (!kinds.contains(AssetReflectionKind.reading) && (pages != null || minutes != null)) {
      throw const FormatException('ページ数・時間は読書記録だけに指定できます');
    }
    final total = amount('verified_amount'); final alcohol = amount('alcohol_amount');
    if (total != null && alcohol != null && alcohol > total) throw const FormatException('酒代が合計額を超えています');
    final memo = json['memo'] ?? '';
    if (memo is! String || memo.length > 2000) throw const FormatException('メモが長すぎます');
    final flow = json['linked_flow_id'];
    if (flow != null && (flow is! String || !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(flow))) throw const FormatException('明細の参照が不正です');
    return AssetCalendarReflection(sourceKey: requiredText('source_key', 200), date: date,
      kinds: kinds, title: requiredText('title', 200), sourceLabel: requiredText('source_label', 200),
      memo: memo, verifiedAmount: total, alcoholAmount: alcohol, pages: pages, minutes: minutes, linkedFlowId: flow as String?);
  }

  Map<String, dynamic> toJson() => {
    'source_key': sourceKey, 'occurred_on': date.toIso8601String().substring(0, 10),
    'kinds': kinds.map((kind) => kind.name).toList(), 'title': title,
    'source_label': sourceLabel, 'memo': memo, 'verified_amount': verifiedAmount,
    'alcohol_amount': alcoholAmount, 'pages': pages, 'minutes': minutes,
    'linked_flow_id': linkedFlowId,
  };
}

/// Multiple sources on the same day count as one day, with explicit unknowns.
class AssetReflectionSummary {
  AssetReflectionSummary(Iterable<AssetCalendarReflection> events)
      : events = events.toList(growable: false);
  final List<AssetCalendarReflection> events;
  int days(AssetReflectionKind kind) => events.where((e) => e.kinds.contains(kind))
      .map((e) => e.date.toIso8601String().substring(0, 10)).toSet().length;
  double get knownAmount {
    final seen = <String>{};
    return events.fold<double>(0, (sum, event) {
      final key = event.linkedFlowId ?? event.sourceKey;
      if (!seen.add(key)) return sum;
      return sum + (event.verifiedAmount ?? 0);
    });
  }
  int get unknownAmounts => events.where((e) => e.verifiedAmount == null &&
      e.kinds.any((k) => k != AssetReflectionKind.reading)).length;
}
