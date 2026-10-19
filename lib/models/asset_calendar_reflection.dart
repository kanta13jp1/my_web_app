import 'receipt_category_allocation.dart';

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
    required this.sourceKey,
    required this.date,
    required this.kinds,
    required this.title,
    required this.sourceLabel,
    this.memo = '',
    this.verifiedAmount,
    this.alcoholAmount,
    this.pages,
    this.minutes,
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
      if (value is! int || value < 0 || value > 1000000) {
        throw FormatException('$key を確認してください');
      }
      return value;
    }

    final day = requiredText('occurred_on', 10);
    final date = DateTime.tryParse(day);
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) ||
        date == null ||
        date.toIso8601String().substring(0, 10) != day) {
      throw const FormatException('日付は実在する年月日にしてください');
    }
    final values = json['kinds'];
    if (values is! List || values.isEmpty) {
      throw const FormatException('種類が必要です');
    }
    final kinds = values
        .map(
          (value) => AssetReflectionKind.values.firstWhere(
            (kind) => kind.name == value,
            orElse: () => throw const FormatException('未対応の種類です'),
          ),
        )
        .toSet();
    final pages = count('pages');
    final minutes = count('minutes');
    if (!kinds.contains(AssetReflectionKind.reading) &&
        (pages != null || minutes != null)) {
      throw const FormatException('ページ数・時間は読書記録だけに指定できます');
    }
    final total = amount('verified_amount');
    final alcohol = amount('alcohol_amount');
    if (total != null && alcohol != null && alcohol > total) {
      throw const FormatException('酒代が合計額を超えています');
    }
    final memo = json['memo'] ?? '';
    if (memo is! String || memo.length > 2000) {
      throw const FormatException('メモが長すぎます');
    }
    final flow = json['linked_flow_id']?.toString();
    if (flow != null && !RegExp(r'^[1-9][0-9]*$').hasMatch(flow)) {
      throw const FormatException('明細の参照が不正です');
    }
    return AssetCalendarReflection(
      sourceKey: requiredText('source_key', 200),
      date: date,
      kinds: kinds,
      title: requiredText('title', 200),
      sourceLabel: requiredText('source_label', 200),
      memo: memo,
      verifiedAmount: total,
      alcoholAmount: alcohol,
      pages: pages,
      minutes: minutes,
      linkedFlowId: flow,
    );
  }

  /// Only explicit expense context is projected; purchases never imply reading.
  static List<AssetCalendarReflection> fromFlows(
    Iterable<Map<String, dynamic>> flows,
  ) {
    final result = <AssetCalendarReflection>[];
    for (final flow in flows) {
      if (flow['action_type'] != 'expense') continue;
      final id = flow['id']?.toString();
      final day =
          DateTime.tryParse(flow['occurred_at']?.toString() ?? '')?.toLocal();
      final description = flow['description']?.toString() ?? '';
      if (id == null || day == null) continue;
      final dining =
          RegExp(r'外食|店内飲食|レストラン|ラーメンショップ|ラーメン店|定食屋').hasMatch(description);
      final outside = RegExp(r'飲み屋|居酒屋|外飲み|飲みに行').hasMatch(description) ||
          (dining && RegExp(r'ビール|飲酒|ハイボール').hasMatch(description));
      final purchase = RegExp(r'酒購入|酒の購入|ビール購入|ビールを購入').hasMatch(description);
      final kinds = <AssetReflectionKind>{
        if (dining) AssetReflectionKind.dining,
        if (outside) AssetReflectionKind.drinkingOut,
        if (purchase) AssetReflectionKind.alcoholPurchase,
      };
      if (kinds.isEmpty) continue;
      final value = flow['amount'];
      final receipt = value is num
          ? ReceiptCategoryAllocation.parse(description, value.abs().toDouble())
          : null;
      result.add(
        AssetCalendarReflection(
          sourceKey: 'flow:$id',
          date: DateTime(day.year, day.month, day.day),
          kinds: kinds,
          title: description.length > 200
              ? description.substring(0, 200)
              : description,
          sourceLabel: '記録済み支出の明示された内容',
          verifiedAmount: value is num &&
                  value.isFinite &&
                  !RegExp(r'金額不明|金額未確認|推定|概算').hasMatch(description)
              ? value.abs().toDouble()
              : null,
          alcoholAmount: receipt?['飲酒'],
          linkedFlowId: RegExp(r'^[1-9][0-9]*$').hasMatch(id) ? id : null,
        ),
      );
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
        'source_key': sourceKey,
        'occurred_on': date.toIso8601String().substring(0, 10),
        'kinds': kinds.map((kind) => kind.name).toList(),
        'title': title,
        'source_label': sourceLabel,
        'memo': memo,
        'verified_amount': verifiedAmount,
        'alcohol_amount': alcoholAmount,
        'pages': pages,
        'minutes': minutes,
        'linked_flow_id': linkedFlowId,
      };
}

/// Multiple sources on the same day count as one day, with explicit unknowns.
class AssetReflectionSummary {
  AssetReflectionSummary(Iterable<AssetCalendarReflection> events)
      : events = events.toList(growable: false);
  final List<AssetCalendarReflection> events;
  int days(AssetReflectionKind kind) => events
      .where((e) => e.kinds.contains(kind))
      .map((e) => e.date.toIso8601String().substring(0, 10))
      .toSet()
      .length;
  double get knownAmount {
    final seen = <String>{};
    return events.fold<double>(0, (sum, event) {
      final key = event.linkedFlowId ?? event.sourceKey;
      if (!seen.add(key)) return sum;
      return sum + (event.verifiedAmount ?? 0);
    });
  }

  double get knownAlcoholAmount {
    final seen = <String>{};
    return events.fold<double>(0, (sum, event) {
      if (!seen.add(event.linkedFlowId ?? event.sourceKey)) return sum;
      return sum + (event.alcoholAmount ?? 0);
    });
  }

  int get unknownAlcoholAmounts => events
      .where(
        (e) =>
            (e.kinds.contains(AssetReflectionKind.drinkingOut) ||
                e.kinds.contains(AssetReflectionKind.alcoholPurchase)) &&
            e.alcoholAmount == null,
      )
      .length;
  int get unknownAmounts => events
      .where(
        (e) =>
            e.verifiedAmount == null &&
            e.kinds.any((k) => k != AssetReflectionKind.reading),
      )
      .length;
}
