# 競合 21社 現況スコアボード (2026-04-20 snapshot)

**生成**: PS版#4 S11 (競合モニタリング専任) — S8/S9/S10 の蓄積情報を 1 枚に集約

**使い方**: 他インスタンスはまずこのファイルから読み、詳細は該当の `competitor-reports/YYYY-MM-DD.md` + `cross-instance-prs/` を参照。

---

## 全体サマリー (2026-04-20 時点)

- **最大脅威**: Slack (Salesforce Agentforce) — **Anthropic Claude + MCP** = 自分株と戦略同一方向
- **急ぎの対応**: Gemini 2.0 Flash-Lite 廃止 (2026-06-01) → `gemini-3.1-flash-lite-preview` 移行
- **チャンス**: Evernote 50件制限 (無料プラン) = 離脱ユーザーの移行先
- **近未来**: Google I/O 2026 (5/19-20) で Gemini 4 + Agent Builder 拡張発表 → 先回り placeholder 準備済
- **Pending cross-instance-pr**: 9 件

---

## 競合 21社 × 脅威度マトリクス

凡例: 🔴 = 直接競合/要即対応 / 🟠 = 間接競合/注視 / 🟢 = 住み分け可 / ⚪ = 未調査 (空白埋め対象)

| # | 競合 | カテゴリ | 2026-04 最新動向 | 脅威度 | 差別化軸 | 対応担当 / Action |
|---|------|---------|-----------------|-------|---------|------------------|
| 1 | **notion** | ノート/ドキュメント | Workers for Agents Dev Preview (GA mid-2026) | 🟠 | 日本語 + 6部署統合 + タグ | 20260421_notion_ai_lp_update.md → VSCode |
| 2 | **evernote** | ノート | 無料プラン 50件制限判明 (前回1000件誤記) | 🟠 | Supabase 同期 + Notion import | LP 移行比較更新 → VSCode (done?) |
| 3 | **moneyforward** | 家計 | AI Cowork (Claude SDK) Early Access / 2030年 ARR ¥15B | 🔴 | 個人向け住み分け | 20260419_moneyforward_counter.md / `finance.personal_summary` 急ぎ → Win |
| 4 | **slack** | チャット/仕事 | **Agentforce 30+ AI 機能 / Claude + MCP** | 🔴🔴 | 個人 × 6部署 × 日本語 × 無料 | 20260420_slack_agentforce_threat.md → VSCode (S9) |
| 5 | **chatwork** | チャット (JP) | kubell: BPaaS × AI agents 戦略 / GraphQL+Go 刷新 (S12) | 🟠 | 個人向け vs 中小企業向け | 定常 watchlist (住み分け明確) |
| 6 | **x (Twitter/xAI)** | SNS/AI | Grok 4.1 Fast (ai-hub 登録済) | 🟢 | SNS は価値消費・自分株は価値増大 | 定期 model update のみ |
| 7 | **animaworks** | アバター AI | 2026-04 新発表なし / Meta Avatars + MetaMe NPC-AI が主戦場 (S12) | 🟢 | フル 3D = philosophy 違反 | 定常 watchlist (深追い不要) |
| 8 | **claude-code** | 開発ツール | Opus 4.7 リリース (hours-long project) | 🟢 | Flutter Web 個人向けは別軸 | ai-hub synthesis 候補 (Win検討中) |
| 9 | **codex (OpenAI)** | 開発ツール | GPT-5 2026Q2 予測 | 🟢 | コーディングツール vs 人生フレームワーク | 定常 watchlist |
| 10 | **netkeiba** | 競馬 | **UMAI予想ビルダー** (ユーザー独自モデル) | 🔴 | PS版#6 horse_racing 戦略再考必要 | S9 で戦略 pivot 示唆 → PS版#6 |
| 11 | **openclaw** | OSS AI agent | 335K★ / 26M MAU / Peter Steinberger→OpenAI / NVIDIA NemoClaw 企業 wrapper (S13) | 🟠 | 日本語 + Flutter Web 即起動 vs CLI/chat bot | 定常 watchlist + OSS 連携余地 |
| 12 | **claude-cowork** | **Anthropic 公式 AI エージェント** | **Claude Cowork GA 2026-04-09 (Pro/Max/Team/Enterprise) / macOS+Win / Drive/Gmail/Sheets/DocuSign 統合 (S13)** | 🔴🔴 | **データ永続化 Supabase vs VM 揮発 / 人生統合 vs 仕事のみ** | 20260420_claude_cowork_threat.md → VSCode+Win (S13・🔴 CRITICAL) |
| 13 | **jobcan** | 勤怠 | DONUTS: AI 自動仕訳 2026-04-13 追加 / 25万社・300万ID (S13) | 🟡 | 個人向け勤怠 (カフェ勉時間計測) | 定常 watchlist |
| 14 | **amazon** | EC/AWS | **Nova 2 Lite ($0.30/M 1M context) + Nova Act** | 🔴 | 個人 LP / Claude 採用 | 20260420_nova2_lite_integration.md → Win (S9) |
| 15 | **google** | 検索/AI | **Gemini 3.1 Flash-Lite / I/O 2026 5/19-20** | 🔴 | Flutter Web 統合 + 日本語 first | 20260420_gemini_flash_lite_migration.md + google_io_2026_preparation.md (S10) |
| 16 | **microsoft** | OS/AI | Azure Foundry 3 マルチモーダル AI (S8) | 🟠 | Flutter Web 軽量 vs 重量企業向け | 定常 watchlist |
| 17 | **discord** | SNS/コミュニティ | Clyde AI = xAI Grok 駆動 (2025 刷新) / 150M MAU (S12) | 🟠 | 個人 AI vs コミュニティ AI | 定常 watchlist |
| 18 | **line** | メッセージ (JP) | **LINE AI ¥750/月 無制限 / 人事AI 10ツール** | 🟠 | ダッシュボード vs 対話のみ | 20260420_line_ai_pricing.md (S9 発行予定) |
| 19 | **facebook (Meta)** | SNS/AI | Llama 4 2026末予測 | 🟢 | SNS 時間消費 vs 価値増大 | 定常 watchlist |
| 20 | **liven** | 栄養/健康 | 実体不明 / 競合=あすけん 1000万会員・カロミル 600万+ (S12) | 🟢 | 専用アプリ NG / 6部署 1 action 化 | lifestyle-hub nutrition action → Win |
| 21 | **github** | コード管理 | Copilot 進化 (codex 経由ai-hub 統合済) | 🟢 | 開発ツール vs 人生ツール | 定常 watchlist |

**空白 (⚪) 残数**: **0社** — 21社すべて分類完了 🎉
→ S12: chatwork/animaworks/discord/liven 4 社再分類
→ S13 (2026-04-20 深夜): openclaw🟠 / **claude-cowork 🔴🔴 (Anthropic 公式 Cowork GA 直接戦略脅威)** / jobcan🟡
→ 次回 (S14) は Google I/O 2026 (5/19-20) keynote 監視に集中

---

## Pending cross-instance-pr 一覧 (11件)

| # | ファイル | 優先度 | 宛先 | 期限 | 背景セクション |
|---|---------|-------|------|------|---------------|
| 1 | `20260419_ef_cleanup_phase2_flutter.md` | - | Win版 | - | (既存) |
| 2 | `20260419_moneyforward_counter.md` | 🔴 | Win版 | 2026-06-30 | MoneyForward GA 前 |
| 3 | `20260419_slack_mcp_integration.md` | - | Win版 | - | (既存) |
| 4 | `20260420_gemini_flash_lite_migration.md` | 🔴 | Win版 | 2026-06-01 | Gemini 2.0 FL 廃止 |
| 5 | `20260420_nova2_lite_integration.md` | 🟡 | Win版 | 2026-05-15 | 1M context ルート |
| 6 | `20260420_perplexity_adobe_firefly.md` | 🟡 | VSCode版 | 2026-05-31 | LP 新脅威 |
| 7 | `20260420_slack_agentforce_threat.md` | 🔴 | VSCode版 | 2026-05-01 | LP Slack 比較行 |
| 8 | `20260420_google_io_2026_preparation.md` | 🟡 | Win+VSCode | 2026-05-18 | I/O 先回り |
| 9 | `20260421_notion_ai_lp_update.md` | 🟡 | VSCode版 | 2026-05-31 | Notion AI |
| 10 | `20260420_lifestyle_nutrition_action.md` | 🟢 | Win版 | 2026-06-30 | lifestyle-hub nutrition action (S12) |
| 11 | **`20260420_claude_cowork_threat.md`** | **🔴🔴** | **VSCode+Win** | **2026-05-01** | **Anthropic 公式 Cowork GA 直接脅威 (S13)** |

**🔴 期限 2026-06-01 以前必須**: #2 (MoneyForward) / #4 (Gemini 廃止) / #7 (Slack LP) / **#11 (Claude Cowork・最優先)**

---

## 優先度付き次回アクション (S12 以降)

### 🔴 今週中
1. Win版: `20260420_gemini_flash_lite_migration.md` 実装確認 (6/1 廃止間近)
2. VSCode版: `20260420_slack_agentforce_threat.md` LP 反映 (本日深夜発行済)

### 🟡 今月中
3. PS版#4 S12: 空白 ⚪ 7社 の深掘り (chatwork/animaworks/discord/liven 優先)
4. Win版: Nova 2 Lite placeholder 埋め
5. PS版#6: 競馬機能の学習教材枠 pivot 検討 (S9 メモ参照)

### 🟢 来月
6. PS版#4 S?: 2026-05-19 Google I/O keynote 監視 → 即日レポート + cross-instance-pr

---

## 戦略的結論

2026-04 時点で自分株式会社の競争優位は以下 **6 軸** に拡張された (S13 で Claude Cowork = Anthropic 直接参入・同技術スタック検出 → 差別化軸 2 本追加):

1. **対象**: 個人 CEO (組織・企業向け SaaS との住み分け)
2. **範囲**: **人生 6 部署統合** (仕事だけの知識労働者 AI に対して ← Claude Cowork)
3. **言語**: 日本語 first (英語中心競合に対して)
4. **価格**: 無料 (seat 課金 Claude Cowork Team $100/月 等に対して)
5. **データ永続化** (S13 追加): **Supabase 永続** vs Claude Cowork VM セッション揮発 — 「昨日の自分」比較 (原則 8) はデータ永続が前提
6. **人生統合** (S13 追加): 6 部署 (R&D / 財務 / マーケ営業 / 人事 / 本社 / 健康) vs 仕事のみ — Claude Cowork は knowledge-work 限定 (CEO 感・ミッション駆動と直結)

→ LP コピーは **6 軸** に集約 (VSCode版タスク)。特に Claude Cowork Pro ユーザー (月 $20 で 2026-04-09 以降契約した層) が **「仕事だけ」→「人生全体」への転換需要** の最有力マーケット。

---

*生成: PS版#4 S11 スコアボード | 2026-04-20 深夜*
*更新: PS版#4 S12 空白 4 社埋め (chatwork 🟠 / animaworks 🟢 / discord 🟠 / liven 🟢) | 2026-04-20 深夜*
*更新: PS版#4 S13 空白 3 社埋め (openclaw 🟠 / **claude-cowork 🔴🔴** / jobcan 🟡) + 差別化軸 4→6 拡張 | 2026-04-20 深夜*
