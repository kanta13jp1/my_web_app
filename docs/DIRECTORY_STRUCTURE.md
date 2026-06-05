# ディレクトリ構成 (主要)

> Win版#132 part 133 (2026-05-05): 旧 CLAUDE.md L401-426 を移行 (= Karpathy 80 行 KPI 達成).

```text
lib/
  main.dart              # ルーティング
  pages/
    landing_page.dart    # LP (比較リンク、FAB CTA)
    comparison_page.dart # 競合比較ページ (1900+ 社)
    user_manual_page.dart
    admin_analytics_page.dart
    election_victory_page.dart # 統一地方選 700 必達管理室
    tech_blog_tracker_page.dart # ブログ投稿管理
    philosophy_page.dart       # 9 原則 + AI 大学動画
supabase/
  functions/             # Deno Edge Functions (= EF / 詳細 docs/EDGE_FUNCTION_LIST.md)
  migrations/            # SQL migration files (= seed_achievements_*.sql など)
docs/
  GROWTH_STRATEGY_ROADMAP.md  # 開発記録 (毎セッション末尾追記)
  PHILOSOPHY.md / AI_DEV_PRINCIPLES.md / AI_FLEET_SYNERGY_PLAYBOOK.md / その他 12 軸 principle docs
  MULTI_INSTANCE_FLEET.md     # 2 instance fleet manifest
  AI_FALLBACK_RUNBOOK.md      # quota 超過 fallback
  daily-reports/         # GHA cron が生成する日次レポート
  cs-notes/              # GHA cron が生成する CS チェックメモ
  weekly-drafts/         # GHA cron が生成する週次 SNS ドラフト
  competitor-reports/    # GHA cron が生成する競合モニタリングレポート
  incident-reports/      # GHA cron が生成するインシデントレポート
  security-audit/        # GHA cron が生成する脆弱性チェックレポート
  knowledge-vault-lint/  # GHA cron が生成する vault 健全性レポート
  concepts/              # wiki_compile.py が生成する Karpathy Compile 出力 (part 132)
  INDEX.md               # wiki_compile.py が生成するマスターインデックス
  cross-instance-prs/    # instance 間 task 依頼 / 規律拡散
  adr/                   # Architecture Decision Records (= 設計判断ログ / docs/adr/README.md)
scripts/
  wiki_compile.py        # Karpathy Compile cycle (part 132)
  memory_ingest.py       # Karpathy Ingest cycle (part 111)
  knowledge_vault_lint.py # Karpathy Lint cycle (part 105)
  notebooklm_issue_crosscheck.py # NotebookLM × Issue cross-check (part 120)
  session_residuals_to_issue.py  # session 残作業 → Issue 自動 (part 118)
  codex_session_check.py         # codex session safety (part 117)
.github/workflows/
  wiki-compile-cron.yml          # daily 02:00 JST (Karpathy Compile)
  session-residuals-sync.yml     # daily 02:30 JST
  notebooklm-issue-crosscheck.yml # daily 04:00 JST
  ai-tool-watch.yml              # daily 06:15 JST
  codex-session-safety-cron.yml  # daily 07:00 JST
  blog-publish.yml + blog-backfill-from-apis.yml + 30+ workflow
memory/
  MEMORY.md              # 全 instance 共有 index (= 各 part memo の一覧)
  project_YYYYMMDD_*.md  # part 別記録 (= Win Claude / Win Codex)
  feedback_*.md          # 成功 / 失敗 / 禁止 pattern
web/
  index.html             # SEO meta tags
  sitemap.xml            # 1900+ URL
  assets/videos/         # self-host MP4 (part 116 〜)
```

## 関連

- [`docs/EDGE_FUNCTION_LIST.md`](EDGE_FUNCTION_LIST.md) — EF 一覧
- [`docs/DEVELOPMENT_ACHIEVEMENTS_FORMAT.md`](DEVELOPMENT_ACHIEVEMENTS_FORMAT.md) — migration 命名 + seed 形式
- [`docs/SCHEDULE_TASKS.md`](SCHEDULE_TASKS.md) — cron 詳細
- [`docs/adr/README.md`](adr/README.md) — ADR (設計判断ログ) 運用ガイド + Index
- [`CLAUDE.md`](../CLAUDE.md) — pointer hub
