# 競合モニタリング (curated by Claude Code) — 2026-04-28

> 自動生成: scheduled-task `competitor-monitoring` (Claude Code Schedule)。
> 対象: CLAUDE.md タスク定義の **14 競合** + Claude API outage 補欠枠。
> 取得方法: WebSearch (EF `check-competitor-updates` は SUPABASE_SERVICE_KEY 不在のためスキップ)。
> GHA `competitor-monitoring.yml` 自動レポート (`2026-04-28.md`) と二重化することで AI 分析層を補強する。

---

## 🔴 高優先 (我々のロードマップに直撃する変更)

### 1. Notion 3.4 — **Workers (server-side JS/TS for AI agents)** + AI Autofill
- 2026-04-14 リリース。AI agent が「Worker」を呼び出して DB クエリ・外部 API・データ変換を実行可能に。
- **影響**: 自分株式会社の **Edge Function ハブ + AI 統合** 戦略と直球で競合。Notion AI が「DB を AI で埋める」UX を標準化 → 我々の `ai-hub` `judgment.get` 等の差別化を再点検する必要あり。
- AI Autofill が DB 列を自動補完 → 我々の `kanban_ai_auto_sort` (PS#2 S49 で SEO 化済) と直接競合。
- ソース: [April 14, 2026 — Notion 3.4 part 2](https://www.notion.com/releases/2026-04-14) / [Notion AI Releases April 2026](https://fazm.ai/blog/notion-ai-releases-april-2026)

### 2. Slack — **30+ AI 機能 (Claude モデル搭載)** by Salesforce
- 2026-03-31 発表。Slackbot が **Claude モデル**で動作 (= Anthropic 戦略提携深化)。
- 主機能: Reusable AI-Skills / Meeting Intelligence (Zoom+Meet+Huddle 横断要約) / Native CRM in chat / AI answer step in workflow。
- **影響**: チームコミュニケーション + 業務自動化が Slack 1 サービスで完結 → 我々の `cross-instance-pr` + WBS + Notion 連携モデルが弱体化リスク。AI 大学キラーコンテンツ (= 第1メディア化戦略) が一段重要に。
- ソース: [Slack AI Update 2026 — eWeek](https://www.eweek.com/news/slack-ai-update-salesforce-slackbot-2026/) / [TechCrunch — 30 new features](https://techcrunch.com/2026/03/31/salesforce-announces-an-ai-heavy-makeover-for-slack-with-30-new-features/)

### 3. OpenAI Codex — **Computer Use + 90+ plugins + Intelligent Automations**
- 2026-04-16 大型更新「Codex for (almost) everything」。
- Computer Use (macOS only at launch) で apps を直接操作 / In-App Browser でページにコメント / gpt-image-1.5 / 90+ plugins (Atlassian Rovo, CodeRabbit, Microsoft Suite, Render, Superpowers 含む) / **Intelligent Automations** = 数日〜数週間にまたがるタスクを自動 wake up して継続。
- **影響**: 我々の **12-instance fleet (Claude Code 10 + Codex 2)** の Codex 役割が「補助 → 半自律」に格上げ可能。`docs/CODEX_WORKFLOW.md` (S13 で確立) を Computer Use + Intelligent Automation 前提で再設計する余地。
- ソース: [Introducing the new Codex — OpenAI](https://openai.com/index/codex-for-almost-everything/) / [Changelog — Codex](https://developers.openai.com/codex/changelog) / [SmartScope April 2026](https://smartscope.blog/en/generative-ai/chatgpt/codex-desktop-major-update-april-2026/)

### 4. Claude Code — **Routines + Ultraplan + Monitor + NO_FLICKER**
- Claude Routines: Mac offline でも cloud で routine 実行 (= 我々の GHA scheduled tasks の上位互換) / Ultraplan: cloud で plan を draft → web editor → run remote or pull local / Monitor tool で background log を tail / Write tool 60% 高速化。
- **影響**: 既に Claude Code Schedule (cs-check / daily-report / ai-university-update / **本タスク**) は activate 済 → routines に移行検討。
- ソース: [Claude Code Whats New](https://code.claude.com/docs/en/whats-new) / [9to5Mac — Claude Code routines](https://9to5mac.com/2026/04/14/anthropic-adds-repeatable-routines-feature-to-claude-code-heres-how-it-works/)

---

## 🟡 中優先 (戦略 watch / 直接機能競合は中程度)

### 5. MoneyForward — **マネーフォワード アカデミア (¥980/月)**
- 2026-04-14 開始。お金に関するオンラインコミュニティ + 体験・交流型学習。
- **影響**: 我々の **AI 大学キラーコンテンツ化** (262 社) と「学習 + コミュニティ + 月額」のビジネスモデルが部分的に重複。MF はお金特化、自分株式会社は **AI 全般 + 自己成長 (人事・財務・営業 6 部署)** で差別化。
- 同時に MF ME 無料会員グラフ拡充 (推移グラフ 6 ヶ月) → 我々の `personal_dashboard` 無料領域と被る。
- ソース: [マネーフォワード アカデミア](https://corp.moneyforward.com/news/release/service/20260414-mf-press-2/) / [MF ME 無料グラフ](https://prtimes.jp/main/html/rd/p/000001624.000008962.html)

### 6. X (Twitter) — **Grok Custom Timelines (Premium iOS)**
- AI が algorithm personalization を理解して 75+ topics (design, robotics, real estate 等) ごとにカスタムタイムライン生成。
- 加えて Grok 翻訳 / Grok image edit block / Audio Articles / X Chat スタンドアロンアプリ (4/25)。
- **影響**: 我々の `post-x-update` EF (@kanta13jp1) は引き続き活用 → Grok 親和コンテンツ (短文 + AI ハッシュタグ) を意識した出稿パターンを検討。
- ソース: [X Custom Timelines — MacRumors](https://www.macrumors.com/2026/04/22/x-custom-timelines-for-premium-users/) / [SocialBee X Updates 2026](https://socialbee.com/blog/twitter-updates/)

### 7. Evernote — AI アシスタント + MP3 音声録音
- AI から task 自動生成 / 旅行プランニング / リマインダー / 検索改善 / floating TOC + collapsible sections / MP3 audio。
- **影響**: 我々の **メモ + AI** 体験 (`public-memo-vs-notion` 第24弾 SEO 済) との比較で、Evernote 側も「AI で task 化」「AI 旅行プラン」へ拡張。
- ソース: [Dave Edwards Media April 2026](https://daveedwardsmedia.com/2026/04/20/updates-toc-aiassist-audio/) / [Evernote 2025 recap (基準)](https://evernote.com/blog/2025-recap)

### 8. Amazon — Anthropic 追加 $5B 投資 + 配送 6 拠点新設
- 2026-04-20 Bloomberg。最大さらに $20B 追加可能。AWS Bedrock 上の Claude 強化 = 我々の **Claude API outage 時 fallback の保険値** が上がる方向。
- **影響**: 戦略上、Anthropic + AWS 強連携は **Multi-AI ワークフロー** にとって追い風。
- ソース: [Bloomberg — Amazon が Anthropic に追加 $5B](https://www.bloomberg.com/jp/news/articles/2026-04-20/TDT7Z4T9NJLV00)

### 9. Cowork (Anthropic) — Dispatch + macOS/Windows 提供
- スマホから Cowork に Dispatch して email チェック / 週次 KPI / Cowork session report 起動。
- OpenClaw 側は 2026-04-25 で TTS + voice + browser automation 拡張。
- **影響**: 我々の **📱 スマホ版 Claude Code** instance を「Dispatch + mobile-bug-triage」混合運用へ進化させる余地。
- ソース: [OpenClaw vs Claude Cowork — Eigent](https://www.eigent.ai/blog/openclaw-vs-claude-cowork) / [Cowork on Windows guide](https://www.remoteopenclaw.com/blog/claude-cowork-windows-guide)

---

## 🟢 低優先 (大きな動きなし / 確認のみ)

| 競合 | 4月の動き | コメント |
|------|----------|----------|
| **Chatwork (kubell)** | 2026 年 4 月の特定アップデート確認できず。2025-10 で Chrome 内蔵 AI auto-correct を追加済。 | watch 継続。 |
| **netkeiba** | 2026-04-13 メンテナンスのみ。新機能 release は確認できず。 | 我々の `horseracing` instance (PS#6) は引き続き 162社化路線で OK。 |
| **Animaworks** | "Animaworks" 単独の April 2026 リリースは確認できず (Vectorworks/Adobe Animate/Animagine 等の noise 結果のみ)。 | 製品名再定義検討。 |
| **ジョブカン (DONUTS)** | 給与計算 4 月改善あり (具体内容は press release 抜粋なし)。 | watch 継続。 |
| **Discord** | 4/6 patch notes は安定性 + accessibility のみ。新機能なし。 | 影響なし。 |
| **LINE** | 2026 年 4 月の単独メジャーアップデートは確認できず。第三者 Discord ⇄ LINE bot のみ。 | watch 継続。 |

---

## アクション提案 (ロードマップ反映候補)

| # | アクション | 担当 | 期限目安 |
|---|-----------|------|----------|
| 1 | Notion Workers / AI Autofill 機能を **/competitors/notion-ai** ページに反映 | PS#4 | 1 週間以内 |
| 2 | Slack 30+ AI 機能 (Claude 搭載) を `growth-hub touchpoints` で言及 (= 我々の AI ファースト戦略への追い風) | PS#5 / VSCode | 2 週間以内 |
| 3 | Codex Computer Use + Intelligent Automations を **`docs/CODEX_WORKFLOW.md`** に追記 (12-instance fleet の Codex 役割を「半自律」へ昇格) | Win 版 | 2 週間以内 |
| 4 | Claude Code Routines に GHA scheduled tasks を 1 件 PoC 移行 (例: cs-check) | PS#1 | 1 ヶ月以内 |
| 5 | MoneyForward アカデミア (¥980/月) を **AI 大学価格戦略** の市場リファレンスとして記録 | PS#3 | 即時 |
| 6 | Evernote AI タスク化 / MP3 を `public-memo-vs-notion` (第24弾) v2 に追記 | PS#2 | 2 週間以内 |

---

## 補足

- 本レポートは **WebSearch** ベース (EF `check-competitor-updates` は無人 scheduled run のため呼出不可)。GHA 側 `competitor-monitoring.yml` の static-template レポートと併読すること。
- 14 競合のうち重要動きは **9 件** / 低優先 5 件。
- 次回 (2026-04-29) は GHA 自動レポートのみで十分。本 curated 版は **週次 (毎月曜)** で十分なケイデンス。

*生成: Claude Code (claude-opus-4-7[1m]) Schedule task `competitor-monitoring` 2026-04-28 07:10 JST*
