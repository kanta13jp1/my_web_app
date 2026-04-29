-- PS#4 S406: 競合3社追加 1042→1045社 (plasmic/dropbox-sign/eversign)
-- SEO: "Plasmic代替"/"Dropbox Sign代替"/"eversign代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S406: 競合3社追加 1042→1045社 (plasmic/dropbox-sign/eversign)',
  'comparison_page.dartにplasmic(ビジュアルページビルダー開発者向けノーコードCMS/no-code/5755FF)/dropbox-sign(電子署名文書ワークフローAPI統合/e-signature/0061FF)/eversign(クラウド電子署名文書管理API/e-signature/00C2B2)の3社追加(1042→1045社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
