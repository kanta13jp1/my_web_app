import 'package:supabase_flutter/supabase_flutter.dart';

/// A recorded-balance checkpoint, not a bank-confirmed closing statement.
class AssetMonthEndSnapshot {
  final String monthKey;
  final DateTime cutoffAt;
  final DateTime capturedAt;
  final double totalAssets;
  final double totalLiabilities;
  final double netWorth;
  final List<Map<String, dynamic>> accounts;
  final int staleAccountCount;

  const AssetMonthEndSnapshot({
    required this.monthKey,
    required this.cutoffAt,
    required this.capturedAt,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.netWorth,
    required this.accounts,
    required this.staleAccountCount,
  });

  factory AssetMonthEndSnapshot.fromJson(Map<String, dynamic> row) {
    return AssetMonthEndSnapshot(
      monthKey: (row['month_key'] as String).substring(0, 7),
      cutoffAt: DateTime.parse(row['cutoff_at'] as String),
      capturedAt: DateTime.parse(row['captured_at'] as String),
      totalAssets: (row['total_assets'] as num).toDouble(),
      totalLiabilities: (row['total_liabilities'] as num).toDouble(),
      netWorth: (row['net_worth'] as num).toDouble(),
      accounts: (row['accounts'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
      staleAccountCount: (row['stale_account_count'] as num).toInt(),
    );
  }
}

/// Missing months are null, never zero or forward-filled observations.
List<AssetMonthEndSnapshot?> monthEndComparison({
  required Iterable<String> monthKeys,
  required Iterable<AssetMonthEndSnapshot> snapshots,
}) {
  final byMonth = {
    for (final snapshot in snapshots) snapshot.monthKey: snapshot,
  };
  return monthKeys.map((key) => byMonth[key]).toList(growable: false);
}

class AssetMonthEndSnapshotService {
  final SupabaseClient client;
  const AssetMonthEndSnapshotService(this.client);

  String get _userId {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('ログインが必要です');
    return userId;
  }

  Future<bool> isEnabled() async {
    final rows = await client
        .from('asset_month_end_snapshot_settings')
        .select('enabled')
        .eq('user_id', _userId)
        .limit(1);
    return rows.isNotEmpty && rows.first['enabled'] == true;
  }

  Future<void> setEnabled(bool enabled) async {
    await client.from('asset_month_end_snapshot_settings').upsert({
      'user_id': _userId,
      'enabled': enabled,
    });
  }

  Future<List<AssetMonthEndSnapshot>> load() async {
    final rows = await client
        .from('asset_month_end_balance_snapshots')
        .select()
        .eq('user_id', _userId)
        .order('month_key', ascending: false)
        .limit(36);
    return rows.map(AssetMonthEndSnapshot.fromJson).toList(growable: false);
  }
}
