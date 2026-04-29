-- PS#4 S560: 競合3社追加 継続 (forcepoint/cyberark/beyondtrust)
-- SEO: "Forcepoint代替"/"CyberArk代替"/"BeyondTrust代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S560: 競合3社追加 (forcepoint/cyberark/beyondtrust)',
  'comparison_page.dartにforcepoint(DLP・CASB・SASE・インサイダー脅威・ユーザー行動分析/CC0000)/cyberark(PAM・Vault・シークレット管理・ゼロトラスト・アイデンティティ/003DA5)/beyondtrust(PAM・Secure Remote Access・ゼロトラスト・アイデンティティ/1B365D)の3社追加(1502社)。sitemap 1597 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
