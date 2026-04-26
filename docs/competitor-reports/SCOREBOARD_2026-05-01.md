# 競合スコアボード 2026-05-01 (May 月次版)

*生成: PS版#4 S70 / 2026-04-26 | 更新予定: 2026-05-01*

---

## 📊 April 2026 競合インテリジェンス月次サマリー

### 今月の主要インテリジェンス

| # | 競合 | 動向 | 脅威度 |
|---|------|------|-------|
| 1 | **Notion** | Custom Agents GA + Japan DC 5月開設 | 🔴 CRITICAL |
| 2 | **Slack** | CRM日本提供開始 + Agentforce統合 | 🔴 HIGH |
| 3 | **GitHub Copilot** | Pro/Pro+ 新規登録一時停止 (機会!) | 🟢 OPPORTUNITY |
| 4 | **OpenAI** | GPT-5.5 API順次拡大 | 🟡 WATCH |
| 5 | **Anthropic** | Claude Opus 4.7 + Sonnet 4.6 発見 | 🟢 ALLY |
| 6 | **Cursor** | Anysphere評価額$9.9B、最速成長AI IDE | 🟡 WATCH |
| 7 | **Microsoft** | Build 2026 (5/19) 直前、Copilot強化発表予定 | 🟡 WATCH |

### April DB 構築完了

| フェーズ | 内容 | 社数 | commit |
|---------|------|-----|--------|
| Phase 1 | competitors テーブル基本化 | 21→172社 | 複数 |
| Phase 2 | competitor_features 10機能 | 172社 | a9cc556c |
| Phase 3 | jp_strength/jp_weakness | 172社 | e4fe33fd |
| Phase 4 | pricing_tier/usd/notes_ja | 41社 | 24fd20b4 |
| Phase 5 | japan_presence_level | 43社 | 6705bf1b |
| Phase 6 | emoji カラム | 46社 | 58cc7f63 |

---

## 🔴 CRITICAL: Notion Japan DC — T-30日 (5月末カウントダウン)

### 2026-05-01 時点の状況

Notion が日本 DC を 2026年5月中に開設する予告を継続。開設されると:
- **J-SOX / 個人情報保護法対応**: データ国内保管で日本企業・官公庁導入が加速
- **日本エンタープライズ販売**: 法人営業に「日本DC完備」が必殺のセールストークになる
- **個人ユーザーへの波及**: 企業導入→ビジネス文脈での個人利用増加

### 自分株式会社の対応優先順 (May 1-31)

| 優先 | アクション | 担当 | 期限 |
|-----|-----------|------|------|
| 1 | comparison_page.dart Supabase fetch移行 (cross-instance-pr実装) | VSCode | 5/10 |
| 2 | 「Notion vs 自分株式会社」比較ページ SEO強化 | PS#2 | 5/15 |
| 3 | Notion Japan DC 開設確認後即 SCOREBOARD_2026-05-XX | PS#4 | 開設日+1 |
| 4 | 個人向け「Notionから乗り換え」オンボーディングフロー | VSCode | 5/31 |

---

## 🟡 WATCH: 5月 Tech Calendar — Big Event Countdown

### Microsoft Build 2026 (予定: 2026-05-19)

| 予測発表 | 自分株式会社への影響 | 対応 |
|---------|------------------|------|
| **Copilot for Work 強化** | Windows + Office AI統合加速 | AI大学 Microsoft entry 更新 |
| **Azure AI + Copilot Studio** | ノーコードAIエージェント構築強化 | n8n/Zapier競合評価 |
| **Power Platform AI** | ビジネスユーザー向けAI民主化 | WBS タスク管理競合強化 |
| **Teams Copilot GA** | Slack対抗の Microsoft Teams AI | 自分株式会社 chat 差別化軸強化 |

**推奨アクション**: Build 2026翌日 (5/20) に microsoft competitor_features 更新。

---

### Google I/O 2026 (2026-05-20) — T-19日

| 製品 | 予測 | 確度 | 自分株式会社への影響 |
|-----|------|-----|------------------|
| **Gemini 4** | ARC-AGI-2 突破, 1M+ context | 高 | AI大学 Gemini entry 大幅更新 |
| **Google Workspace AI** | Docs/Sheets/Meet AI エージェント | 高 | cloud-office 脅威レベル見直し |
| **NotebookLM Pro** | API + 商用プラン発表 | 中 | PS#4 調査ツール強化 |
| **Android 16** | On-device Gemini / Health Connect AI | 中 | モバイル UX 差別化 |
| **Firebase AI** | Firebase + Gemini 統合 | 中 | 自分株式会社 EF の Gemini統合 |

**推奨アクション**: I/O翌日 (5/21) に SCOREBOARD_2026-05-21 緊急版 + competitor_features google/gemini 一括更新。

---

## 🟢 OPPORTUNITY: GitHub Copilot 混乱期

### 現状 (2026-04-26 確認)

- **Pro/Pro+ 新規登録一時停止**: エージェント並列実行急増でインフラコスト増大
- **Claude Opus 4.x 削除**: ProプランからOpusモデルが全削除
- **代替探し中のユーザー**: Claude Code・Windsurf・Cursorへの移行検討が増加

### 獲得チャンス戦略

1. **AI大学コンテンツ**: 「GitHub Copilot代替完全ガイド」記事 (PS#2 担当) → SEO集客
2. **比較ページ**: `/vs-github` で Copilot vs 自分株式会社を訴求
3. **タイミング**: 5月中に記事公開 → Copilot 混乱期の検索流入を獲得

---

## 📈 5月 competitor_features 更新タスク

月次 DB 更新対象 (PS#4 May セッション):

| 競合 | 更新理由 | 変更予定フィールド |
|-----|---------|----------------|
| `notion` | Japan DC 開設後確認 | japan_presence_level: strong→dominant |
| `notion-ai` | Custom Agents GA | competitor_features.ai_assistant update |
| `slack` | Slack CRM JP対応確認 | competitor_features.crm update |
| `google` | I/O発表後 | threat_level + key_features 更新 |
| `microsoft` | Build発表後 | competitor_features 全件見直し |
| `github` | Copilot混乱期の現状確認 | pricing_notes_ja update |
| `cursor` | $9.9B評価 + 機能追加確認 | funding_or_valuation, key_features |

---

## 🇯🇵 Japan Presence ランキング (2026-05-01)

### Dominant (日本市場支配的)

| 競合 | 推定日本MAU | 強み |
|-----|-----------|-----|
| LINE | 9,600万 | 日本国民的アプリ / LINEヤフー |
| X (Twitter) | 6,700万 | 日本は世界屈指の利用密度 |
| Amazon | 5,000万+ | EC + Prime + AWS |
| Google | 1.2億+ | 検索76%シェア / Workspace |
| Microsoft | 4,000万+ | Office 365 / Teams |
| MoneyForward | 1,500万 | 家計管理 No.1 |
| Chatwork | 550万 | 中小企業チャット No.1 |
| netkeiba | 1,700万 | 競馬情報 No.1 |
| Cloudsign | 300万 | 電子署名 No.1 |
| freee | 400万 | クラウド会計 No.1候補 |
| SmartHR | 8万社 | HR SaaS No.1 |

### 5月 Notion の変化予測

- **現状**: `strong` (3,000万ユーザー推定 / 日本語UI)
- **5月DC開設後**: `dominant` に格上げ → 日本エンタープライズ獲得加速
- **対抗戦略**: 「個人CEO専用」差別化で企業ツール化を回避

---

*PS#4 S70 / 2026-04-26 作成 / 実測値は 2026-05-01 更新予定*
