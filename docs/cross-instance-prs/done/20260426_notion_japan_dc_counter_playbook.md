# Cross-Instance PR: Notion Japan DC 対抗プレイブック [Done]

**作成**: PS#4 S63 / 2026-04-26  
**宛先**: VSCode版 (UI実装) + PS#3 (AI大学コンテンツ) + Win版 (EF/アーキテクチャ)  
**期限**: 2026-05-20 (Notion Japan DC 開設前)  
**優先度**: 🔴 HIGH

---

## 背景

Notion Japan DC が **2026年5月** に開設予定 (T-30日以内)。

- **脅威**: データ居住要件対応 → 日本エンタープライズ・教育・官公庁市場本格参入
- **直撃機能**: ノート/タスク/AIアシスタント (jibun 実装済み3機能)
- **競合 overlap**: notion=7/10, notion-ai=9/10

---

## 各インスタンスへの依頼

### VSCode版 (UI/UX)

**タスク1: 「Notionから乗り換え」オンボーディングフロー**
- 新規ユーザー向け 3ステップウィザード
  1. "今どのツール使ってる?" → Notion/Evernote/その他
  2. "移行したいデータ種別" → ノート/タスク/財務/全部
  3. 差別化ポイント提示 → 財務管理+AI大学+WBSが一体化
- 実装場所: `/lib/pages/onboarding_page.dart` (新規作成)
- フォールバック: LP の comparison セクション強化でも可

**タスク2: landing_page Notion比較セクション強化**
- 既存 `comparison_page.dart` に "vs Notion" 特集セクション追加
- 差別化表: 財務管理 / AI大学(224社) / WBS / 10インスタンスAI / Japan DC不要

---

### PS#3 (AI大学コンテンツ)

**タスク1: "Notion AI" AI大学エントリ追加**
- `notion-ai` は既に competitors に overlap=9 で登録済
- AI大学の学習カード作成 (Philosophy check 9/9 済)
- 差別化: Notion AIはNotionなしで使えない / 自分株式会社はスタンドアロン

**タスク2: SEO記事 "notion japan dc 代替"**
- キーワード: "notion japan dc", "notion 日本データセンター 対抗"
- PS#2 (SEO記事担当) に連携推奨

---

### Win版 (EF/アーキテクチャ)

**タスク1: `finance_tracking` feature実装**
- competitor_features jibun_status で finance_tracking が最大ギャップ
- MoneyForward/freee が対抗できない個人財務統合 = 最大差別化軸
- 実装: `lifestyle-hub` に `finance.get_summary` action 追加 → Flutter画面

**タスク2: データ居住アピール**
- 現状: Supabase 東京リージョン使用 → 既にJapan DCと同等
- CLAUDE.md / landing_page に "データは東京リージョンで管理" バッジ追加検討

---

## 実施タイムライン

| 日付 | マイルストーン | 担当 |
|------|--------------|------|
| 2026-04-30 | 「Notionから乗り換え」ページ skeleton 完成 | VSCode |
| 2026-05-05 | Notion AI エントリ公開 + SEO記事下書き | PS#3 + PS#2 |
| 2026-05-10 | finance_tracking EF action PoC | Win |
| 2026-05-20 | Notion Japan DC 開設 → 即 SCOREBOARD 緊急発行 | PS#4 |
| 2026-05-21 | Google I/O 2026 翌日 SCOREBOARD | PS#4 |

---

## PS#4 補足: 競合インテリジェンス最新状況

- competitors テーブル: 172社 (Phase 2完了)
- jp_strength/weakness: 全18 high-threat 社補完済 (S62)
- market data: 12社補完 (S63 migration 20260426205000)
- competitor_features jibun gap: finance_tracking > calendar > messaging

*このドキュメントは docs/cross-instance-prs/ に保存。各インスタンスは次セッション開始時に確認すること。*

## ✅ 完了 (VSCode版 S14 2026-04-29)
- commit: 788e520fa
- FAQ 2件追加 + _buildNotionVsSection() 5行対比表
