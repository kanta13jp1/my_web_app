import 'package:my_web_app/models/asset_liability_workbook.dart';

class AssetManagementFixedCostSummaryEntry {
  const AssetManagementFixedCostSummaryEntry({
    required this.name,
    required this.amount,
    required this.dayOfMonth,
    required this.isLegacy,
    required this.isPaid,
  });

  final String name;
  final int amount;
  final int dayOfMonth;
  final bool isLegacy;
  final bool isPaid;
}

class AssetManagementFixedCostSummary {
  const AssetManagementFixedCostSummary({required this.entries});

  final List<AssetManagementFixedCostSummaryEntry> entries;

  int get total => entries.fold<int>(0, (sum, entry) => sum + entry.amount);

  int get legacyUnpaidTotal => entries
      .where((entry) => entry.isLegacy && !entry.isPaid)
      .fold<int>(0, (sum, entry) => sum + entry.amount);

  int get recurringEntryCount =>
      entries.where((entry) => !entry.isLegacy).length;

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;
}

/// 旧 subscriptions と現在の recurring fixed costs を月単位で統合する。
///
/// 現在の recurring fixed costs を正として先に採用し、同じ名称・支払日・金額の
/// 旧 subscriptions 行は二重計上しない。
class AssetManagementFixedCostSummaryService {
  const AssetManagementFixedCostSummaryService();

  AssetManagementFixedCostSummary build({
    required DateTime month,
    Iterable<Map<String, dynamic>> legacySubscriptions =
        const <Map<String, dynamic>>[],
    Iterable<AssetRecurringFixedCost> recurringFixedCosts =
        const <AssetRecurringFixedCost>[],
    double? usdJpyRate,
  }) {
    final target = DateTime(month.year, month.month, 1);
    final entries = <AssetManagementFixedCostSummaryEntry>[];
    final seenKeys = <String>{};

    void addEntry(AssetManagementFixedCostSummaryEntry entry) {
      if (entry.name.isEmpty || entry.amount <= 0) {
        return;
      }
      final key = _dedupeKey(entry);
      if (!seenKeys.add(key)) {
        return;
      }
      entries.add(entry);
    }

    for (final cost in recurringFixedCosts) {
      if (!cost.appliesToMonth(target.month)) {
        continue;
      }
      addEntry(
        AssetManagementFixedCostSummaryEntry(
          name: cost.name.trim(),
          amount: cost.resolveJpyAmount(usdJpyRate).round(),
          dayOfMonth: cost.paymentDay.clamp(1, 31).toInt(),
          isLegacy: false,
          isPaid: false,
        ),
      );
    }

    for (final subscription in legacySubscriptions) {
      final dueDate = DateTime.tryParse(
        subscription['due_date']?.toString() ?? '',
      );
      if (dueDate == null ||
          dueDate.year != target.year ||
          dueDate.month != target.month) {
        continue;
      }
      final amount = _readAmount(
        subscription['price'] ?? subscription['amount'],
      );
      addEntry(
        AssetManagementFixedCostSummaryEntry(
          name: (subscription['service_name'] ?? subscription['name'] ?? '')
              .toString()
              .trim(),
          amount: amount,
          dayOfMonth: dueDate.day,
          isLegacy: true,
          isPaid: subscription['is_paid'] == true,
        ),
      );
    }

    entries.sort((a, b) {
      final dayCompare = a.dayOfMonth.compareTo(b.dayOfMonth);
      if (dayCompare != 0) {
        return dayCompare;
      }
      return a.name.compareTo(b.name);
    });
    return AssetManagementFixedCostSummary(
      entries: List<AssetManagementFixedCostSummaryEntry>.unmodifiable(entries),
    );
  }

  String _dedupeKey(AssetManagementFixedCostSummaryEntry entry) {
    final normalizedName = entry.name.trim().toLowerCase().replaceAll(
          RegExp(r'\s+'),
          '',
        );
    return '$normalizedName|${entry.dayOfMonth}|${entry.amount}';
  }

  int _readAmount(Object? value) {
    if (value is num) {
      return value.round();
    }
    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        )?.round() ??
        0;
  }
}
