/// 寄付・クラウドファンディングプロジェクトモデル。
///
/// `lifestyle-hub` の `donation.list` (`{success, projects: [hub_data 行]}`)
/// を解析する純データモデル。実フィールドは `metadata.title` /
/// `metadata.description` / `metadata.goal_amount` / `metadata.raised_amount`
/// / `metadata.status`。旧実装は flat キー読みで全プロジェクトが
/// 「タイトル不明 / ¥0 / ¥0」表示だった。
library;

import 'hub_data_parsing.dart';

class DonationProject {
  const DonationProject({
    required this.title,
    required this.description,
    required this.goalAmount,
    required this.raisedAmount,
    required this.status,
  });

  final String title;
  final String description;
  final num goalAmount;
  final num raisedAmount;
  final String status;

  /// 達成率 (0.0-1.0 にクランプ / 目標 0 は 0.0)。
  double get progress {
    if (goalAmount <= 0) return 0.0;
    final ratio = raisedAmount / goalAmount;
    return ratio.clamp(0.0, 1.0).toDouble();
  }

  factory DonationProject.fromMap(Map<String, dynamic> raw) {
    return DonationProject(
      title: hubString(hubField(raw, 'title')),
      description: hubString(hubField(raw, 'description')),
      goalAmount: hubNum(hubField(raw, 'goal_amount')),
      raisedAmount: hubNum(hubField(raw, 'raised_amount')),
      status: hubString(hubField(raw, 'status')),
    );
  }

  static List<DonationProject> listFromResponse(dynamic data) =>
      hubRowsFromResponse(data, 'projects')
          .map(DonationProject.fromMap)
          .toList();
}
