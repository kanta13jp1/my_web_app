class LandingTrialInstantPreview {
  final String action;
  final String reason;

  const LandingTrialInstantPreview({
    required this.action,
    required this.reason,
  });
}

LandingTrialInstantPreview buildLandingTrialInstantPreview(String prompt) {
  final normalized = prompt.trim().toLowerCase();

  bool containsAny(Iterable<String> terms) {
    return terms.any(normalized.contains);
  }

  if (containsAny(const <String>['お金', '家計', '支出', '固定費', '貯金', '請求', '予算'])) {
    return const LandingTrialInstantPreview(
      action: '直近30日の明細を開き、金額が最も大きい固定費を1件書き出す',
      reason: '契約変更はせず、まず10分で見直し候補を事実から1件に絞れるためです。',
    );
  }

  if (containsAny(const <String>['学習', '勉強', '資格', '試験', '読書', '講座'])) {
    return const LandingTrialInstantPreview(
      action: '学ぶテーマを1つだけ選び、最初に確認する教材を開く',
      reason: '計画を増やす前に、10分で着手できる入口を1つ作れるためです。',
    );
  }

  if (containsAny(const <String>['健康', '体調', '睡眠', '運動', '疲れ', '休む'])) {
    return const LandingTrialInstantPreview(
      action: '今日いちばん気になる体調を1つメモし、無理なくできる10分の行動を決める',
      reason: '大きな目標ではなく、今の状態を確認して安全に始められるためです。',
    );
  }

  if (containsAny(const <String>['仕事', '案件', 'タスク', '締切', '連絡', '先送り'])) {
    return const LandingTrialInstantPreview(
      action: '止まっている作業を1件開き、次に確認する相手か資料を1つ決める',
      reason: '優先順位を考え続ける前に、10分で進捗を作れるためです。',
    );
  }

  return const LandingTrialInstantPreview(
    action: 'いま困っていることを1文にし、最初に確認する相手か資料を1つ決める',
    reason: '結論を急がず、10分で次の判断に必要な情報を1つ増やせるためです。',
  );
}
