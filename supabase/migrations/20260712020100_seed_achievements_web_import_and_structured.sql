-- WEB版 2026-07-12: AI 行動提案 2 (XLSX/DOCX インポート) + 3 (構造化タスク管理)
INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  'XLSX/DOCXインポート対応 (Notion移行0ステップ強化)',
  'Excel (XLSX) と Word (DOCX) のインポートに対応。ZIP+XML を archive/xml でクライアント解析し、XLSX は Title/Content/Tags 列を検出してノート化 (ヘッダ無しシートは行単位)、DOCX は段落を結合して1ノート化。OfficeDocumentParser を純関数として切り出し VM テストを追加。',
  '2026-07-12'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = 'XLSX/DOCXインポート対応 (Notion移行0ステップ強化)'
);

INSERT INTO public.development_achievements (title, description, completed_at)
SELECT
  '構造化タスク管理 (GitHub Issue Fields相当)',
  'feature_requests / growth_plans に priority (p0-p3) / effort (xs-xl) / target_date を追加。機能要望公開ページで優先度・工数・期日をチップ表示し、管理ダッシュボードから設定可能に。roadmap.progress EF も priority/effort を返却。',
  '2026-07-12'
WHERE NOT EXISTS (
  SELECT 1 FROM public.development_achievements
  WHERE title = '構造化タスク管理 (GitHub Issue Fields相当)'
);
