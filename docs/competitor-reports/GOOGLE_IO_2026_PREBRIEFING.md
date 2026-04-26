# Google I/O 2026 競合脅威 事前ブリーフィング

**作成**: PS#4 S64 / 2026-04-26  
**カウントダウン**: T-**24日** (2026-05-20開催)  
**即時アクション期限**: 2026-05-19 (前日 SCOREBOARD 発行)

---

## 🔴 最高警戒: Gemini 4 + Android AI 発表

### 予測発表内容と自分株式会社への影響

| 製品 | 予測 | 脅威レベル | 自分株式会社の対応 |
|------|------|-----------|-----------------|
| **Gemini 4** | ARC-AGI-2 84.6% 超え / マルチモーダル強化 | 🔴 HIGH | AI大学 Gemini 4 entry 即日追加 (PS#3) |
| **Google Workspace AI** | Docs/Sheets エージェント統合 | 🔴 HIGH | cloud-office 競合カテゴリ強化 |
| **NotebookLM Pro** | Deep Research 商用 API 発表 | 🟡 MEDIUM | PS#4 ツールとして活用継続 |
| **Android AI** | On-device Gemini Nano 強化 | 🟡 MEDIUM | モバイル UX 差別化ネタ |
| **Project Astra** | マルチモーダル継続 AI アシスタント | 🔴 HIGH | ai-assistant 機能の競合強化 |

### Google Workspace AI 詳細リスク分析

- **現状**: Google Docs/Sheets/Slides に AI エージェント統合 β
- **I/O後予測**: GA (一般提供) + 日本語対応拡充
- **直撃機能**: document_management (jibun: partial), ai_assistant (jibun: done)
- **ユーザー数**: Google Workspace 全世界 3B+ アカウント → 到達範囲が圧倒的
- **対策**: 「個人 CEO ライフ OS」= Google が提供できない個人財務+習慣化+目標管理の統合

---

## 🟡 注視: NotebookLM Pro API 公開

### 自分株式会社への影響
- **ポジティブ**: PS#4 の競合調査コストが下がる (NotebookLM API 直接呼び出し)
- **ネガティブ**: 競合他社も NotebookLM 品質の調査ツールが使える
- **対策**: master-brain の蓄積量 (= 過去の意思決定・文脈) で差別化

---

## 🟡 注視: Jules by Google (自律型コーディング)

### 現状 (2026-04-26)
- competitors.id = `jules-google` / overlap=6 / jp_strength: Google エコシステム統合
- I/O での発表予測: GA + GitHub Actions 統合
- 自分株式会社への影響: 開発インスタンス (PS#4/PS#6) の効率向上に使える可能性

---

## 📋 I/O 当日チェックリスト (PS#4 担当)

### 2026-05-20 当日タスク
- [ ] Gemini 4 の正確なモデル ID / コスト / ベンチマークを確認
- [ ] Google Workspace AI の新機能リスト収集
- [ ] NotebookLM Pro API の価格・仕様確認
- [ ] competitor_features: Google Workspace AI の has_feature 更新
- [ ] `jules-google` jp_strength/jp_weakness 更新

### 2026-05-21 翌日タスク (SCOREBOARD 緊急発行)
- [ ] `SCOREBOARD_2026-05-21.md` 生成 → docs/competitor-reports/
- [ ] 最重要脅威 TOP3 を cross-instance-pr で Win版/VSCode版に通知
- [ ] AI大学: Gemini 4 entry 追加依頼 (PS#3 宛 cross-instance-pr)
- [ ] WBS update: competitor-monitoring progress 更新

---

## 📊 I/O 後の competitor_features 更新計画

### 更新対象 (優先順)

| competitor_id | 更新内容 | 優先度 |
|--------------|---------|------|
| `google` | ai_assistant=true (Gemini 4) / document_management=true (Workspace AI) | 🔴 |
| `google-workspace` (新規) | 全機能フル評価 | 🔴 |
| `jules-google` | has_feature 全評価 / jp_strength/weakness | 🟡 |
| `notion-ai` | Custom Agents GA状況確認 | 🟡 |

---

## 🏆 競合優位サマリー (I/O 後も維持可能な差別化)

| 自分株式会社 | Google が追いつけない理由 |
|------------|------------------------|
| 個人財務 + 確定申告 | Google は会計機能を持たない (税務はサードパーティ任せ) |
| WBS + 事業化 KPI | 個人起業家向け。Google は法人向けに偏重 |
| 10インスタンス AI 並行 | Google は単一 AI。マルチインスタンス協調は独自 |
| AI大学 (226社) | Google の競合製品を教材化 = 逆手戦略 |
| 個人 CEO ライフ OS | Google は「仕事ツール」。全生活統合は独自領域 |

---

*次回 SCOREBOARD: Notion Japan DC 開設後 (2026-05 中旬以降) + Google I/O 翌日 (2026-05-21)*
