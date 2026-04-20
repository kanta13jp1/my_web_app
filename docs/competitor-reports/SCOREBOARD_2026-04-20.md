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
| 1 | **notion** | ノート/ドキュメント | Workers for Agents Dev Preview (GA mid-2026) / **Custom Agents 35-50% コスト削減 (GPT-5.4 Mini/Nano + Haiku 4.5 で credit 10 分 1) + Autofill 連携 (S16) / [S17] 無料試用 2026-05-03 終了 → 2026-05-04 から $10/1000 credit 課金開始 (Business+Enterprise add-on)** | 🔴 | 日本語 + 6部署統合 + タグ | 20260421_notion_ai_lp_update.md → VSCode |
| 2 | **evernote** | ノート | 無料プラン 50件制限判明 (前回1000件誤記) | 🟠 | Supabase 同期 + Notion import | LP 移行比較更新 → VSCode (done?) |
| 3 | **moneyforward** | 家計/法人 | **AI Cowork = 法人バックオフィス専用 (2026-07 GA / Claude SDK+MCP) — 個人家計は対象外 (S14 住み分け確定)** | 🟠 | 個人 CEO vs 組織バックオフィス | 20260419_moneyforward_counter.md / `finance.personal_summary` 継続 → Win |
| 4 | **slack** | チャット/仕事 | **TDX 2026 (04-15): 60+ MCP tool + Agentforce Vibes 2.0 (Claude Sonnet 4.5 default / Dev Edition 無料) / Agentforce 360 = Mobile+ChatGPT+Claude+Gemini+Teams 全対応 (S14) / [S17] Headless 360 (everything は API/MCP/CLI) + Agentforce Experience Layer (UI 分離 → Slack/Mobile/ChatGPT/Claude/Gemini/Teams で同一 agent をネイティブ描画) + Agent Script OSS (github.com/salesforce/agentscript) + AgentExchange marketplace (10K Salesforce + 2.6K Slack + 1K agents 統合)** | 🔴🔴 | 個人 × 6部署 × 日本語 × 無料 | 20260420_slack_agentforce_threat.md → VSCode (S9) |
| 5 | **chatwork** | チャット (JP) | kubell: BPaaS × AI agents 戦略 / GraphQL+Go 刷新 (S12) | 🟠 | 個人向け vs 中小企業向け | 定常 watchlist (住み分け明確) |
| 6 | **x (Twitter/xAI)** | SNS/AI | Grok 4.1 Fast (ai-hub 登録済) / **Grok 4.3 beta 4-agent team (Grok+Harper+Benjamin+Lucas) SuperGrok Heavy 限定 — "AI 自己組織化" vs 自分株 "人間 CEO 指揮" (S16)** | 🟠 | SNS は価値消費・自分株は価値増大・CEO 感 (原則 1) | LP コピーに「人間 CEO vs AI 自己組織化」軸追加検討 → VSCode |
| 7 | **animaworks** | アバター AI | 2026-04 新発表なし / Meta Avatars + MetaMe NPC-AI が主戦場 (S12) | 🟢 | フル 3D = philosophy 違反 | 定常 watchlist (深追い不要) |
| 8 | **claude-code** | 開発ツール | Opus 4.7 リリース (hours-long project) | 🟢 | Flutter Web 個人向けは別軸 | ai-hub synthesis 候補 (Win検討中) |
| 9 | **codex (OpenAI)** | 開発ツール | GPT-5 2026Q2 予測 | 🟢 | コーディングツール vs 人生フレームワーク | 定常 watchlist |
| 10 | **netkeiba** | 競馬 | **UMAI予想ビルダー** (ユーザー独自モデル) | 🔴 | PS版#6 horse_racing 戦略再考必要 | S9 で戦略 pivot 示唆 → PS版#6 |
| 11 | **openclaw** | OSS AI agent | 335K★ / 26M MAU / Peter Steinberger→OpenAI / NVIDIA NemoClaw 企業 wrapper (S13) | 🟠 | 日本語 + Flutter Web 即起動 vs CLI/chat bot | 定常 watchlist + OSS 連携余地 |
| 12 | **claude-cowork** | **Anthropic 公式 AI エージェント** | **Claude Cowork 研究PV 01-30 / GA 02-24 / Pro $20 組込み 04-09 / 長文課金廃止 03-13 / Excel+Sheets+Gmail+Slack+DocuSign+FactSet (S14) / [S17] Computer Use 解禁 (Pro/Max・2026-04 build 以降): Claude が画面操作 (file/dev tool/browser) を直接実行 — Connectors > Browser > Screen の優先順 + Analytics API + OpenTelemetry + Enterprise pricing 改定 (flat $200 → $20/seat + usage-based)** | 🔴🔴 | **個人 6 部署 / Supabase 永続 / 日本語 first (3 軸)** | 20260420_claude_cowork_threat.md → VSCode+Win (S13・🔴 CRITICAL) |
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
*更新: PS版#4 S14 Claude Cowork pricing 詳細 + MoneyForward バックオフィス専用判明 (🔴→🟠) + Slack TDX 2026 最新化 | 2026-04-20 深夜*

---

## Watchlist Backlog (S15 追加・21社リスト外)

21社リストには入らないが、将来の脅威度変化に備えて定常監視する競合。

| 競合 | カテゴリ | 2026-04 動向 | 判定 | 住み分け根拠 |
|------|---------|-------------|------|-------------|
| **Cursor** (Anysphere) | AI コーディング IDE | **$50B 調達協議中 (mid-04・S25 2 社検証済) / $2B ARR 達成 (Jan2025 $100M→13 ヶ月で 20倍・Feb2026 到達) / 2026 末 $6B run rate 予測 / a16z+Thrive co-lead+NVIDIA strategic+Battery Ventures (新規・S25 追加)** ※前期 $9.9B (Jun2025) → $29.3B (Nov2025) → $50B 噂 (Apr2026) と **10 ヶ月で 5 倍** | 🟢 watchlist | コーディングツール vs 人生フレームワーク — 領域不重複 |
| **Cognition** (Windsurf+Devin) | AI 開発エージェント | Windsurf + Devin 統合 / $10.2B 評価 / LogRocket SWE-Bench #1 | 🟢 watchlist | 自律 SWE エージェント vs 個人 CEO 6 部署 |
| **Lovable** | AI Web 生成 | $100M ARR を 8 ヶ月で達成 / $2B 評価 | 🟢 watchlist | "vibe coding" で Web 生成 vs 生活統合ダッシュボード |
| **Replit** (S16 追加) | AI Web 開発環境 | $3B → **$9B 評価 (6 ヶ月で 3 倍)** / Q1 2026 AI funding $242B (VC 80%) 背景 | 🟢 watchlist | オンライン IDE vs 人生 6 部署 — 領域不重複 |
| **Anthropic Labs Claude Design** | AI デザイン SaaS | 2026-04-17 GA / prompt→prototype 2 回 / Canva CEO 署名の native 統合 / Pro $20+ | 🟠 ツール採用検討 | VSCode版 が `/claude-design-handoff` と併用判断 (Rule 21) |
| **OpenAI Codex Desktop** (S22 追加・S24 訂正) | AI 個人タスク自動化 | **2026-04-17 大型 update**: Computer Use (macOS sandbox VM・foreground 非干渉) + Multiple agents parallel + Memory preview + **20+ plugins (Box/Figma/Linear/Notion/Sentry/Slack/Gmail/HF・self-serve publish 未対応)** + In-app browser / 3M weekly devs / Computer Use は Claude とパリティ・**plugin ecosystem は Claude 優位 (423 vs 20+ = 約 20 倍)** | 🟠 **routing 判断待ち** | 個人 Mac の手先自動化 vs 人生 6 部署経営 — 領域不重複だが ai-hub routing に影響 |

**扱い**: Cursor / Cognition / Lovable は **LP 比較表に追加しない**。理由:
- いずれも「仕事 knowledge-work の内側」を争う競合で、自分株式会社の軸 1 (対象=個人 CEO) / 軸 2 (範囲=人生 6 部署) と重ならない
- 21社リストに入れると比較表が knowledge-work 寄りに傾き、差別化メッセージが弱まる

*更新: PS版#4 S15 watchlist backlog 3 社 (Cursor / Cognition / Lovable) + Claude Design 詳細 | 2026-04-20 深夜*
*更新: PS版#4 S16 notion 🟠→🔴 (Custom Agents 10x コスト減) / x 🟢→🟠 (Grok 4.3 4-agent team) / Cursor ARR 訂正 + Replit $9B 追加 | 2026-04-20 深夜 late*
*更新: PS版#4 S17 Notion 課金開始日 (2026-05-04) / Claude Cowork **Computer Use Pro/Max 解禁** + Enterprise pricing 改定 ($20/seat+usage) / Slack TDX **Headless 360 + Experience Layer + Agent Script OSS + AgentExchange** / Cursor 再訂正 ($9.9B→$50B 9 ヶ月で 5 倍・$2B ARR) | 2026-04-20*
*更新: PS版#4 S18 **AgentExchange 逆輸入 PR 起票** (Jibun Inc Slack agent・Philosophy 6/9 + AI-DEV 5/7 両クリア → Win版 handoff) | 2026-04-20 late*
*更新: PS版#4 S19 Notion 5/4 課金 **D-14 SNS 3 本 PR 起票** (4/28 本A / 5/2 本B / 5/4 本C → PS#2 handoff + VSCode LP補記) | 2026-04-20 late*
*更新: PS版#4 S20 5 並列 delta — S18 AgentExchange **HOLD 判定** (Salesforce Partner 必須 HIT) → **MCP 直接公開 代替 PR 起票** / Notion credit 不足 "pause" 挙動発見 / Gemini 4 (ARC-AGI2 84.6% / 2M / sub-300ms) | 2026-04-20 夕*
*更新: PS版#4 S21 🔴 **OpenAI Codex Desktop 4/17 Computer Use + 90 plugin + MCP** = Claude Code と機能パリティ+α → 個人タスク自動化 Claude 一強崩壊 / Evernote 4 plan 再編 (Personal/Professional retire) / MoneyForward **AI Cowork** 7/launch (法人 BO 住み分け追認) | 2026-04-20 夜*
*更新: PS版#4 S22 SCOREBOARD に S18-S21 delta 集約 + OpenAI Codex 行を Watchlist Backlog に追加 + 差別化軸 7 目「AI 手段の分散 vs 特化」を追加検討 | 2026-04-20 夜 late*
*訂正: PS版#4 S24 **Codex 90 plugin → 20+ plugins (self-serve 未対応) に訂正** + Claude Code = 423 plugins / 2,849 skills / 177 agents (+ Desktop Extensions .mcpb / Plugins for Cowork ページ・claude.com/plugins) で **plugin ecosystem は Claude が約 20 倍優位**。S21「Claude 一強崩壊」narrative を「Computer Use はパリティ、ただし plugin ecosystem は Claude 優位」に修正 | 2026-04-20 夜 last*
*検証: PS版#4 S25 Cursor 2 社交差検証済 — ARR Jan2025 $100M→Feb2026 $2B は **13 ヶ月** (not 16) / $9.9B→$50B は **10 ヶ月** (not 9) / 新投資家 Battery Ventures 追加 / $50B は依然「in talks」未確定 / S24 教訓 (2 社交差検証) 即適用 | 2026-04-20 夜 last 2*

---

## S17 戦略インパクト (3 大 delta)

### 1. Notion 課金開始日が確定 — 2026-05-04
- 5/3 まで Custom Agents 試用無料 → 5/4 から $10/1000 credit (Business/Enterprise add-on)
- **[S26] 2 社交差 audit 済** (notion.com/help/custom-agent-pricing 公式 + matthiasfrank.de + connex.digital):
  - **1 回 run あたりの credit 消費 = 約 11-33 credits** (= **$0.11-$0.33/run**)
  - 公式「45-90 runs/1000 credits」 vs 独立分析「30-60 runs/1000 credits」 → conservative 採用で **30-90 runs/1000 credits** 範囲
  - credits は月次リセット (roll over 不可) = 「使わなくても消える」pressure
  - model/tool/steps により変動大 → 複雑 workflow で更にコスト悪化
- 自分株式会社の機会: **5/4 直前 (4/28 〜 5/3) に「Notion 課金移行 = $$$」の SEO/SNS 弾を投下** → 無料 6 部署統合への転換訴求
- **SNS 弾強化材料** (PS#2 本A 修正版 4/23+ dispatch 用): 「Notion で 1 日 10 回 agent を動かすと月 $33-$99。自分株式会社は $0 (完全無料)」
- VSCode版 LP に「Notion Custom Agents 5/4 から $10/1000 credit 課金 (1 回 $0.11-$0.33)」比較行を追加検討

### 2. Claude Cowork Computer Use 解禁 (Pro/Max・2026-04 build 以降)
- Claude が画面操作 (file 開く/dev tool/browser) を直接実行 — Connectors > Browser > Screen 優先順
- Pro $20/月 ユーザーは即時利用可能 (Team/Enterprise は除外)
- 自分株式会社への影響: **「人生 6 部署統合」軸の優位は維持** (Cowork は依然 knowledge-work 専用) だが、 **「データ永続化」軸 (差別化軸 5)** が更に重要に — Computer Use は session 揮発のため
- Anthropic Enterprise pricing 改定 ($200 flat → $20/seat + usage-based) で **Cowork 上位プランの月額予測が困難 → 「自分株式会社 = 完全無料・予測可能」の SNS 訴求弾**
- **[S27] 2 社交差 audit 済** (`claude.com/pricing` 公式 + The Register + PYMNTS + Gizmodo + npifinancial + Kingy AI = 5 独立報道):
  - **転換時期**: 2025-11 から renewal-based 段階移行 / 2026-02 で all-inclusive Enterprise seat 化 (chat + Code + Cowork)
  - **新構造 3 点**: (1) 強制コミット枠 (Anthropic 推定の月次 token 量を pre-pay・実消費が下回っても請求) (2) 従来の 10-15% 大口割引廃止 (3) per-token 単価は不変 (= 値上げ要因は割引廃止)
  - **インパクト**: heavy users で **2-3 倍コスト増** (Fredrik Filipsson / Redress Compliance 試算 + npifinancial 「TCO 上昇」分析) → SNS 弾強化材料
  - **SNS 弾強化フレーズ** (PS#2 本C 4/23+ dispatch 用): 「Anthropic Enterprise = 強制コミット枠で実消費を下回っても請求。自分株式会社は完全無料・コミット枠ゼロ」
  - **負債 framing** (Qiita BS 原則): 「コミット枠 = 月次強制負債、未消費分は資産化されず消える」

### 3. Slack TDX Headless 360 + Experience Layer (S14 詳報の追加詳細)
- **Agentforce Experience Layer**: agent action と UI を分離 → 同一 agent が Slack/Mobile/ChatGPT/Claude/Gemini/Teams でネイティブ描画
- **Agent Script OSS**: 言語仕様/grammar/parser/compiler 全公開 (github.com/salesforce/agentscript)
- **AgentExchange marketplace**: Salesforce 10K + Slack 2.6K + Agentforce 1K = 14K+ 統合検索
- 自分株式会社への対応: **Slack agent エコシステムに「逆輸入」検討** — `enterprise-hub` から Slack へ 6 部署サマリーを push する agent を Agent Script で書いて AgentExchange 公開 → 個人 CEO が法人 Slack で自分株式会社情報を扱える流入経路

---

## S21 戦略インパクト (2 大 delta)

### 1. OpenAI Codex Desktop 4/17 大型 update — Computer Use パリティ達成 (🟠・S24 訂正)

- **Computer Use (macOS)**: sandbox VM 内で mouse/keyboard 制御・foreground 非干渉
- **Multiple agents parallel**: 同一 Mac で複数 agent 同時実行
- **Memory preview**: 過去対話 + personal preferences + corrections 記憶
- **~~90+ plugins~~ 20+ plugins** (Box/Figma/Linear/Notion/Sentry/Slack/Gmail/HF 等・**self-serve publish は未対応**)
- **In-app browser**: 3M weekly devs 向け PR review / multi-terminal / SSH devbox
- → Claude Code Desktop (Cowork) と **Computer Use はパリティ** 達成
- → **ただし plugin ecosystem は Claude が依然優位**: Claude Code 423 plugins / 2,849 skills / 177 agents (+ .mcpb Desktop Extensions / claude.com/plugins で Cowork 用 plugin も) vs Codex 20+ plugins
- **S24 訂正**: 当初の「Claude 一強崩壊」は過剰評価 — 正確には「Computer Use カテゴリで Codex が catch-up、ただし plugin ecosystem は Claude 約 20 倍優位」

**自分株式会社への影響**:
- **直接 (Low)**: LP 比較表に「3 者棲み分け」行追加 (OpenAI Codex = 手先自動化 / Claude = Knowledge-work / 自分株式会社 = 人生 6 部署経営)
- **間接 (Medium-High)**: ai-hub の **モデル routing 戦略** 再検討が必要
  - Computer Use / 長期 memory 必須タスクを Codex へ routing する action 追加候補
  - cost-hub に Codex tier 追加検討 (per-session cost が Claude Sonnet より低い場合)
- 起票: `docs/cross-instance-prs/20260420_openai_codex_desktop_threat.md` (Win版 + VSCode版)

### 2. Notion Custom Agent "無言 pause" 挙動 (S20 発見・SNS 弾強化材料)

- live Custom Agent が credit 不足 → **次の monthly service date で pause** (通知なし可能性大)
- ユーザー視点: 「あれ、agent が動いてない?」と気付いたときに既にデータ欠落
- 対比: 自分株式会社 = **課金概念が存在しない → credit 残高ウォッチ自体が不要**
- S19 本A (4/28 D-6) に訴求材料として追補済 (`20260504_notion_paywall_d14.md` 追加訴求材料セクション)

---

## S22 差別化軸 7 目 — AI 手段の分散 vs 特化 (検討中)

S21 の OpenAI Codex 参入で、個人 AI 市場は「単一 AI で全部やる」から「用途別 AI の組み合わせ」へ移行中:

- Claude Code = プロジェクト文脈 + 長期ミッション駆動
- OpenAI Codex = Computer Use + plugin ecosystem
- Cursor = IDE 内補完 + コーディング
- 自分株式会社 = **AI 手段を選ばず 6 部署軸で統合するハブ** (ai-hub routing)

→ 軸 7 案: **「AI 手段の分散」= 単一 vendor 依存しない = CEO 的リスク管理 (原則 1・7 整合)**
→ Win版 routing 判断結果が出たら LP 軸 7 を正式採用する

**S24 補足**: 機能パリティ論は Computer Use のみ。**plugin ecosystem は Claude が Codex の約 20 倍優位**なので「どの AI を選ぶか」の答えは「plugin ecosystem で Claude、Computer Use は両方、自分株式会社は 6 部署軸で統合」が正確。SNS 弾 (S23 PR) の framing も「Claude 一強崩壊」ではなく「Claude 優位維持でも 6 部署軸は別問題」に訂正。

