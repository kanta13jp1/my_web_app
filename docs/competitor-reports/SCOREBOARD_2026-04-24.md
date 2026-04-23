# 競合 21社 現況スコアボード (2026-04-24 snapshot)

**生成**: PS版#4 (競合モニタリング専任) — SCOREBOARD_2026-04-20 からの差分集約
**前回スナップショット**: `SCOREBOARD_2026-04-20.md` (4日前・大幅変化あり)

**使い方**: 他インスタンスはまずこのファイルから読み、詳細は該当の `competitor-reports/YYYY-MM-DD.md` + `cross-instance-prs/` を参照。

---

## 全体サマリー (2026-04-24 時点)

- **最大脅威**: **Natural AI Phone 本日発売** + Slack (Salesforce×Google Cloud 横断)
- **急ぎの対応**: Gemini 2.0 Flash-Lite 廃止 (2026-06-01) → `gemini-3.1-flash-lite-preview` 移行
- **チャンス (二重)**: Evernote Free = **50ノート/1ノートブック** + Notion 5/4課金 = 二段階離脱ウェーブ
- **新発見**: GPT-5.5 (Spud) 2026-04-23リリース / OpenAI モデル更新ペースが週次レベルに加速
- **Google I/O 2026**: 5/19-20 (25日後) — 先回り準備必須
- **Pending cross-instance-pr**: 4件 (緊急度付き)

---

## 競合 21社 × 脅威度マトリクス (2026-04-24 更新)

| # | 競合 | カテゴリ | 2026-04 最新動向 | 脅威度 | 差別化軸 | 対応担当 / Action |
|---|------|---------|-----------------|-------|---------|------------------|
| 1 | **notion** | ノート/ドキュメント | **5/4から$10/1000 credit課金開始** (1回 $0.11-$0.33) / Agent Skills + Calendar/Mail/Slack統合 GA (4/14) / n8n MCP連携 / Voice input Desktop / credit増加ループ形成中 | 🔴 | 日本語 + 6部署統合 + 無料・無制限 | 20260424_notion_agent_skills_counter.md → VSCode (5/3期限) |
| 2 | **evernote** | ノート | **4プラン再編確定**: Free=50ノート/1ノートブック / Starter ¥$8.25/月 / Advanced $14.17/月 / Teams $24.99/月 / 2年で料金2倍 / 15年ユーザーの大規模離脱継続 | 🟠 | Supabase同期 + Notion import + 無料無制限 | LP移行比較表更新 → VSCode (done?) |
| 3 | **moneyforward** | 家計/法人 | AI Cowork (7月GA) = **Claude Agent SDK + MCP** で複数agent並列実行 (経理・税務・財務・HR・法務) / 2030年目標AI経由150億円 / 個人家計は対象外確認済 | 🟠 | 個人CEO vs 組織バックオフィス (住み分け確定) | `finance.personal_summary` 継続 → Win |
| 4 | **slack** | チャット/仕事 | **Google Cloud連携 (4/22)**: Slack+Google Workspace間でAI横断ワークフロー / Agentforce+Gemini Enterprise統合 / IDMC BigQueryコネクター提供開始 | 🔴🔴 | 個人 × 6部署 × 日本語 × 無料 | 20260420_slack_agentforce_threat.md → VSCode |
| 5 | **chatwork** | チャット (JP) | kubell: BPaaS × AI agents 戦略 / 変化なし | 🟠 | 個人向け vs 中小企業向け | 定常 watchlist |
| 6 | **x (Twitter/xAI)** | SNS/AI | Grok 4.3 beta 4-agent team (SuperGrok Heavy限定) — 変化なし | 🟠 | SNS は価値消費・自分株は価値増大・CEO感 | 定常 watchlist |
| 7 | **animaworks** | アバター AI | 変化なし | 🟢 | フル3D = philosophy違反 | 定常 watchlist |
| 8 | **claude-code** | 開発ツール | **Claude Opus 4.7 GA** (software engineering強化 / vision高解像度) / Claude Code大型更新 (大セッション67%高速化 / MCP起動改善) / Claude Managed Agents public beta | 🟢 | Flutter Web個人向けは別軸 | ai-hub synthesis候補 |
| 9 | **codex (OpenAI)** | 開発ツール | **GPT-5.5 (Spud) 2026-04-23リリース** (paid subscribers向け) / GPT-5.4 mini rollout継続 / 6週でGPT-5.4→5.5とモデル更新ペース加速 | 🟠 | コーディングツール vs 人生フレームワーク | **ai-hub model update依頼 → Win (新規)** |
| 10 | **netkeiba** | 競馬 | UMAI予想ビルダー (ユーザー独自モデル) — 変化なし | 🔴 | PS版#6 horse_racing戦略 | 定常監視 |
| 11 | **openclaw** | OSS AI agent | 変化なし | 🟠 | 日本語 + Flutter Web即起動 vs CLI/chat | 定常 watchlist |
| 12 | **claude-cowork** | Anthropic公式AIエージェント | Computer Use Pro/Max 解禁継続 / **Opus 4.7 powered** (4/17〜) / Enterprise pricing $20/seat+usage | 🔴🔴 | 個人6部署 / Supabase永続 / 日本語first (3軸) | 20260420_claude_cowork_threat.md → VSCode+Win |
| 13 | **jobcan** | 勤怠 | AI自動仕訳 2026-04-13追加済 | 🟡 | 個人向け勤怠 | 定常 watchlist |
| 14 | **amazon** | EC/AWS | Nova 2 Lite ($0.30/$2.50M) / Nova Act (agent機能) / **ai-hub routing再考必要** | 🔴 | 個人LP / Claude採用 | 20260420_nova2_lite_integration.md → Win |
| 15 | **google** | 検索/AI | **Gemini 3.1 Pro GA** / Gemma 4ファミリー API公開 / **Gemini Embedding 2 preview (マルチモーダル)** / Google Cloud $750M partner fund (4/22) / Chrome統合 + auto browse preview / **I/O 2026 5/19-20** | 🔴 | Flutter Web統合 + 日本語first | 20260424_google_gemini_embedding2.md → Win / 20260420_gemini_flash_lite_migration.md → Win |
| 16 | **microsoft** | OS/AI | Azure Foundry 3 — 変化なし | 🟠 | Flutter Web軽量 vs 重量企業向け | 定常 watchlist |
| 17 | **discord** | SNS/コミュニティ | 変化なし | 🟠 | 個人AI vs コミュニティAI | 定常 watchlist |
| 18 | **line** | メッセージ (JP) | ¥750/月 無制限 (GPT-4o/4o-mini) / 機能narrow 5項目のみ / code interpreter/deep research/GPTs 全無し | 🟠 | Flutter Web + 6部署統合 vs 対話 + feature-narrow | LP訂正完了 (VSCode 4/24 db32be24) |
| 19 | **facebook (Meta)** | SNS/AI | Llama 4 進行中 | 🟢 | SNS時間消費 vs 価値増大 | 定常 watchlist |
| 20 | **liven** | 栄養/健康 | 変化なし | 🟢 | 専用アプリNG / 6部署1 action化 | lifestyle-hub nutrition action → Win |
| 21 | **github** | コード管理 | Claude Opus 4.7 Copilot対応継続 | 🟢 | 開発ツール vs 人生ツール | 定常 watchlist |

---

## 2026-04-20 → 2026-04-24 差分サマリー

| 変化 | 前 (4/20) | 後 (4/24) | 影響 |
|------|----------|----------|------|
| Natural AI Phone | 4/24発売予告 | **本日¥1/月で発売** | 脅威具体化 |
| GPT model | GPT-5.4 | **GPT-5.5 (Spud) 4/23リリース** | ai-hub要更新 |
| Notion Agent | Skills未発表 | **Skills + Calendar/Mail/Slack GA** | credit増加ループ |
| Slack | TDX 2026完了 | **Google Cloud AI横断連携追加** | 法人向け統合強化 |
| Google Gemini | Flash-Lite廃止監視中 | **3.1 Pro GA / Embedding 2 preview** | I/O前哨戦 |
| Evernote | 50件制限 (既知) | **4プラン再編詳細判明** ($8.25〜) | 離脱ウェーブ加速 |
| LP 差別化軸 | 6軸 | **8軸 (VSCode 4/24完了)** | LINE訂正+vendor分散軸追加 |

---

## 二重チャンスウィンドウ (2026-05-04前後)

**Evernote + Notion の同時離脱ウェーブ**が2026年5月に重なる可能性:

```
Evernote:
  → Free = 50ノート/1ノートブック (すでに制限済み)
  → 料金2年で2倍 ($40-50 → $80-120+)
  → 「Notion に移行しよう」ユーザー増加中

Notion:
  → 5/4から Custom Agents 課金開始 ($0.11-$0.33/run)
  → 月次creditリセット = 使わなくても損
  → 「Notionも課金か...」ユーザーが次の移行先を探す

自分株式会社:
  → 完全無料 / ノート制限なし / Notion importあり / Evernote移行パス必要
  → 5/4直前〜5/7頃のSNS弾タイミングが最重要
```

**PS#2へのアクション依頼**: 5/4 SNS弾 (既存dispatch計画) に「Evernote→Notion→自分株式会社 二段階移行」フレームを追加検討。

---

## Pending cross-instance-pr 更新版 (4/24時点)

| # | ファイル | 優先度 | 宛先 | 期限 | ステータス |
|---|---------|-------|------|------|-----------|
| 1 | `20260424_notion_agent_skills_counter.md` | 🔴 | VSCode版 | 2026-05-03 | **未着手** |
| 2 | `20260420_gemini_flash_lite_migration.md` | 🔴 | Win版 | 2026-06-01 | 未確認 |
| 3 | `20260424_natural_phone_launch_confirmed.md` | 🟡 | Win版 | 2026-05-15 | 未着手 |
| 4 | `20260424_google_gemini_embedding2.md` | 🟢 | Win版 | 2026-05-31 | 未着手 |
| 5 | `20260420_claude_cowork_threat.md` | 🔴🔴 | VSCode+Win | 2026-05-01 | 未確認 |
| 6 | `20260420_slack_agentforce_threat.md` | 🔴 | VSCode版 | 2026-05-01 | 未確認 |
| 7 | `20260504_notion_paywall_d14.md` | 🔴 | PS#2 | 2026-04-28 | dispatch待ち |
| 8 | `20260421_lp_differentiation_axes_s29_s31.md` | - | VSCode版 | - | **完了** (4/24 db32be24) |

**🔴 最急**: #1 (VSCode 5/3期限) / #7 (PS#2 4/28dispatch) / #5/#6 (Win+VSCode 5/1)

---

## 戦略的競合優位 8軸 (2026-04-24 確定版)

> 2026-04-24 時点で自分株式会社の競争優位は **8軸** に拡張済 (4/24 VSCode LP反映 db32be24)

1. **対象**: 個人CEO (組織・企業向けSaaSとの住み分け)
2. **範囲**: **人生6部署統合** (仕事だけの知識労働者AI — Claude Cowork/Notionとの差別化)
3. **言語**: 日本語first (英語中心競合に対して)
4. **価格**: **完全無料** (Notion $0.11-$0.33/run / LINE ¥750 / Claude Cowork $20/seat+usage)
5. **データ永続化**: **Supabase永続** vs Claude Cowork VM揮発 / LINE セッション単位
6. **人生統合**: 6部署 (R&D/財務/マーケ/人事/本社/健康) vs 仕事のみ
7. **vendor分散**: Anthropic + Gemini + AWS = 3社分散 / LINE AI = OpenAI単一依存
8. **feature depth**: 対話+21サービス統合 vs LINE AI 5項目 / Evernote 50ノート制限

---

## Watchlist Backlog (2026-04-24更新)

| 競合 | 2026-04 動向 | 判定 | 住み分け根拠 |
|------|-------------|------|-------------|
| **Cursor** | $50B調達協議中 / $2B ARR / Battery Ventures追加 | 🟢 watchlist | コーディングツール vs 人生フレームワーク |
| **Cognition** (Windsurf+Devin) | $10.2B評価 / SWE-Bench #1 | 🟢 watchlist | 自律SWEエージェント vs 個人CEO 6部署 |
| **Lovable** | $100M ARR 8ヶ月 / $2B評価 | 🟢 watchlist | vibe coding vs 生活統合 |
| **Replit** | $400M Series D @ $9B Georgian主導 / ARR 24× / **Agent 4 digital canvas** (non-programmer pivot) | 🟠 watchlist-upgraded | pivot警戒: non-programmer層で軸接近可能性 |
| **Anthropic Labs Claude Design** | 2026-04-17 GA / Opus 4.7 powered | 🟠 ツール採用検討 | VSCode版が`/claude-design-handoff`で判断 |
| **OpenAI Codex Desktop** | Computer Use + 20+ plugins + Memory preview / **GPT-5.5 powered** | 🟠 routing判断待ち | ai-hub routing再検討 (GPT-5.5でどう変わるか) |
| **Natural AI Phone** (SoftBank) | **2026-04-24本日発売** / ¥1/月 / SoftBank独占1年 / 9アプリ横断 | 🟠 **NEW** Q2要監視 | OS統合 vs Web App哲学的KPIは代替困難 |

---

## Google I/O 2026 先回り準備 (5/19-20)

**予測発表内容** (前回S10のplaceholderベース + 4/24時点情報補強):

| 予測 | 根拠 | 対応タスク |
|------|------|-----------|
| Gemini 4 GA | Gemma 4 → Gemini 4系の自然な進化 / ARC-AGI2 84.6% | ai-hub model列追加 → Win |
| Gemini Embedding 2 GA | 現在preview → I/Oで正式化 | ai-hub検索強化 → Win (4/24 cross-instance-pr発行済) |
| Google Workspace AI統合強化 | Salesforce連携 (4/22) の延長線 | LP Google行更新 → VSCode |
| Android AI Phone対抗機能 | Natural AI Phoneへの応答 | 要監視 |
| Gemini 3.1 Flash-Lite GA | 現在preview (廃止6/1 = 移行促進) | 既存migration taskに影響なし |

---

## 次回PS#4アクション (優先順)

1. **5/3-4頃**: Notion 5/4課金後のSNS反応モニタリング → 離脱ウェーブ測定
2. **5/19-20**: Google I/O 2026 即日レポート作成 → SCOREBOARD更新
3. **毎週**: Evernote離脱→Notion→自分株式会社 二重チャンスウィンドウ追跡
4. **随時**: GPT-5.5による競合ai-hub routing変化をWin版にhandoff

---

*生成: PS版#4 競合モニタリング専任 | 2026-04-24*
*SCOREBOARD_2026-04-20.md のフル更新版。前回から4日間の主要変化を集約。*
