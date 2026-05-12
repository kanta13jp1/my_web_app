-- PS#4 S626: 競合3社追加 依存関係管理 (gitguardian/dependabot/renovate)
-- SEO: "GitGuardian代替"/"Dependabot代替"/"Renovate代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S626: 競合3社追加 (gitguardian/dependabot/renovate)',
  'comparison_page.dartにgitguardian(シークレット検出SaaS・リアルタイム監視・350+検出器・インシデント管理/4A90D9)/dependabot(GitHub自動依存関係更新・セキュリティアラート・PR自動作成・無料/0D6EFD)/renovate(自動依存関係更新・高カスタマイズ・グループ更新・Mend製/009CA6)の3社追加(1699社)。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
