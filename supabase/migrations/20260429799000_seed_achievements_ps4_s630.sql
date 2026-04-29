-- PS#4 S630: 競合3社追加 パッケージマネージャー (pnpm/yarn-berry/cargo)
-- SEO: "pnpm代替"/"Yarn Berry代替"/"Cargo代替" 検索流入獲得

INSERT INTO public.development_achievements (title, description, completed_at)
VALUES (
  'PS#4 S630: 競合3社追加 (pnpm/yarn-berry/cargo)',
  'comparison_page.dartにpnpm(高速ディスク効率パッケージ管理・シンボリックリンク・モノレポ/F69220)/yarn-berry(PnP・ゼロインストール・制約エンジン・モノレポ・プラグイン/2C8EBB)/cargo(Rust公式パッケージ管理・ビルド・crates.io・ワークスペース/DEA584)の3社追加(1717社)。sitemap 1813 URLs。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
