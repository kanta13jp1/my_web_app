-- Session daily-development 2026-04-10: 予算・財務プランナー全面刷新 + テーマ修正
INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    '予算・財務プランナー 全面刷新 (MoneyForward/Amazon Rufus対抗)',
    'budget_financial_planner_page.dart を128行スタブから本実装へ全面刷新。4タブ構成（概要KPI/カテゴリ別予算/AI節約アドバイス/将来シミュレーション）を実装。budget-financial-planner Edge Function連携。ai-assistant Edge Functionによる支出データ分析・節約提案3点生成。複利計算シミュレーター（初期資産・月積立・年利回り・運用期間で将来資産額を試算）。カテゴリ別予算設定・進捗バー・超過アラート。支出・収入追加ボトムシート。競合: MoneyForward / Amazon Rufus「Buy for Me」対抗。flutter analyze 0件維持。',
    '2026-04-10'
  ),
  (
    'テーマシステム第3弾: Colors.black87/black.alpha/grey → colorScheme置換 (18件)',
    'rewards_page.dart: AppBar.foregroundColor Colors.black87→Colors.black。morning_briefing_page.dart: Colors.black.withValues(alpha:0.05)→surfaceContainerHighest / isCompleted Colors.grey:Colors.black→colorScheme.onSurface tokens。asset_management_page.dart: Colors.black12→outlineVariant (2件)。全ファイル flutter analyze 0件維持。VSCode#17 テーマ統一プロジェクト継続。',
    '2026-04-10'
  ),
  (
    'feature-request-manager / notify-feature-request Edge Function全面改善',
    'feature-request-manager: GitHub Issue自動作成 (GITHUB_PAT連携) / Resendメール通知 / FeatureRequestRow/GitHubIssueResult/AuthenticatedUser型定義 / ルーター化リファクタリング (handleGet/handlePost/handleDelete)。notify-feature-request: automation-auth統合・FeatureRequestRow/AppFeedbackRow型追加・通知テンプレートHTMLリッチ化。deno lint 0件維持。',
    '2026-04-10'
  )
ON CONFLICT DO NOTHING;
