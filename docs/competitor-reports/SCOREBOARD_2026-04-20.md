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
| 5 | **chatwork** | チャット (JP) | 目立った AI 発表なし (S10) | ⚪ | 個人向け vs 組織向け | 次回 S12 深掘り候補 |
| 6 | **x (Twitter/xAI)** | SNS/AI | Grok 4.1 Fast (ai-hub 登録済) | 🟢 | SNS は価値消費・自分株は価値増大 | 定期 model update のみ |
| 7 | **animaworks** | アバター AI | 新規動向なし (S10 調査) | ⚪ | — | 定常 watchlist |
| 8 | **claude-code** | 開発ツール | Opus 4.7 リリース (hours-long project) | 🟢 | Flutter Web 個人向けは別軸 | ai-hub synthesis 候補 (Win検討中) |
| 9 | **codex (OpenAI)** | 開発ツール | GPT-5 2026Q2 予測 | 🟢 | コーディングツール vs 人生フレームワーク | 定常 watchlist |
| 10 | **netkeiba** | 競馬 | **UMAI予想ビルダー** (ユーザー独自モデル) | 🔴 | PS版#6 horse_racing 戦略再考必要 | S9 で戦略 pivot 示唆 → PS版#6 |
| 11 | **openclaw** | ? (未解明) | — | ⚪ | — | 次回 S12 実体調査候補 |
| 12 | **claude-cowork** | ? (社内呼称?) | — | ⚪ | — | 次回 S12 実体調査候補 |
| 13 | **jobcan** | 勤怠 | 新規 AI 発表なし (S10) | ⚪ | 個人向け勤怠 (カフェ勉時間計測等) | 定常 watchlist |
| 14 | **amazon** | EC/AWS | **Nova 2 Lite ($0.30/M 1M context) + Nova Act** | 🔴 | 個人 LP / Claude 採用 | 20260420_nova2_lite_integration.md → Win (S9) |
| 15 | **google** | 検索/AI | **Gemini 3.1 Flash-Lite / I/O 2026 5/19-20** | 🔴 | Flutter Web 統合 + 日本語 first | 20260420_gemini_flash_lite_migration.md + google_io_2026_preparation.md (S10) |
| 16 | **microsoft** | OS/AI | Azure Foundry 3 マルチモーダル AI (S8) | 🟠 | Flutter Web 軽量 vs 重量企業向け | 定常 watchlist |
| 17 | **discord** | SNS/コミュニティ | 最新動向未調査 | ⚪ | 個人 CEO vs コミュニティ | 次回 S12 深掘り候補 |
| 18 | **line** | メッセージ (JP) | **LINE AI ¥750/月 無制限 / 人事AI 10ツール** | 🟠 | ダッシュボード vs 対話のみ | 20260420_line_ai_pricing.md (S9 発行予定) |
| 19 | **facebook (Meta)** | SNS/AI | Llama 4 2026末予測 | 🟢 | SNS 時間消費 vs 価値増大 | 定常 watchlist |
| 20 | **liven** | 栄養/健康 | 最新動向未調査 | ⚪ | 健康部署統合 | 次回 S12 深掘り候補 |
| 21 | **github** | コード管理 | Copilot 進化 (codex 経由ai-hub 統合済) | 🟢 | 開発ツール vs 人生ツール | 定常 watchlist |

**空白 (⚪) 残数**: 7社 — chatwork / animaworks / openclaw / claude-cowork / jobcan / discord / liven
→ 次回 (S12) は空白埋めに集中

---

## Pending cross-instance-pr 一覧 (9件)

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

**🔴 期限 2026-06-01 以前必須**: #2 (MoneyForward) / #4 (Gemini 廃止) / #7 (Slack LP)

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

2026-04 時点で自分株式会社の競争優位は以下 4 軸に集約される (Slack Agentforce の Claude + MCP 採用で技術は commodity 化):

1. **対象**: 個人 CEO (組織・企業向け SaaS との住み分け)
2. **範囲**: 人生 6 部署統合 (仕事だけの競合に対して)
3. **言語**: 日本語 first (英語中心競合に対して)
4. **価格**: 無料 (seat課金型競合に対して)

→ LP コピーの統一メッセージをこの 4 軸に集約すべき (VSCode版 タスク)。

---

*生成: PS版#4 S11 スコアボード | 2026-04-20 深夜 — 次回 S12 で空白埋め*
