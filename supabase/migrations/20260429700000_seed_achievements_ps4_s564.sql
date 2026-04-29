-- PS#4 S564: 競合3社追加 継続 (jamf/kandji/microsoft-intune)
-- SEO: "Jamf代替"/"Kandji代替"/"Microsoft Intune代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S564: 競合3社追加 (jamf/kandji/microsoft-intune)',
  'comparison_page.dartにjamf(Apple特化MDM・Jamf Pro/Now・ゼロタッチ展開・セキュリティ/0075D3)/kandji(Apple MDM・Blueprint自動化・コンプライアンス・ゼロタッチ/7C3AED)/microsoft-intune(UEM・MDM/MAM・Windows/iOS/Android・条件付きアクセス/0078D4)の3社追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
