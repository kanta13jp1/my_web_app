-- PS#4 S551: 競合3社追加 継続 (owasp-zap/metasploit/invicti)
-- SEO: "OWASP ZAP代替"/"Metasploit代替"/"Invicti代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S551: 競合3社追加 (owasp-zap/metasploit/invicti)',
  'comparison_page.dartにowasp-zap(OSS WebアプリDASTスキャナー・自動化・CI/CD統合・OWASP公式・無料/339900)/metasploit(ペネトレーションテスト・エクスプロイトフレームワーク・OSS・認定セキュリティリサーチ/004BA0)/invicti(証拠ベースDASTスキャン・誤検知0保証・自動化・エンタープライズ/2196F3)の3社追加(1475社)。sitemap 1570 vs-URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
