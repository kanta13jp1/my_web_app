-- PowerShell 全体管理セッション #5 実績シード 2026-03-31

INSERT INTO development_achievements (title, description, completed_at)
VALUES
  (
    'サイトマップ43URL更新・新ページ追加 (categories/medical-notes/financial-report)',
    'web/sitemap.xmlにcategories・medical-notes・financial-reportを追加し40→43URLに拡充。ApiPlaygroundPage・FinancialReportPage・PaymentChannelLedgerPageのルート追加も統括コミット。flutter analyze 0件維持。',
    '2026-03-31'
  ),
  (
    'ApiPlaygroundPage・FinancialReportPage・PaymentChannelLedgerPage実装',
    'API操作実験用のApiPlaygroundPage・財務レポートのFinancialReportPage・決済チャネル台帳のPaymentChannelLedgerPageを実装。main.dartとhome_tool_catalogにルートを追加。MoneyForward競合機能としての財務管理機能を強化。',
    '2026-03-31'
  ),
  (
    'local-election-intelligence Geminiスキーマ拡張 (electionSchedules/timeSeriesData)',
    'docs/index.tsのGeminiレスポンススキーマにelectionSchedules（選挙スケジュール）とtimeSeriesData（時系列推移）を追加。国民民主党の地方議員数トレンド可視化とLineChart連携を強化。',
    '2026-03-31'
  )
ON CONFLICT DO NOTHING;
