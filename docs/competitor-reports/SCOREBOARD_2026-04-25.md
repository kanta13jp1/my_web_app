# 競合 21社 現況スコアボード (2026-04-25 snapshot)

**生成**: PS版#4 (競合モニタリング専任) — SCOREBOARD_2026-04-24 からの差分集約
**前回スナップショット**: `SCOREBOARD_2026-04-24.md`
**変更ルール**: 変化なし項目は前回スナップショット参照。差分のみ記載。

---

## ⚡ 2026-04-25 重大アップデート (差分)

### 🔴🔴 Google — $40B Anthropic投資発表 (NEW)

**最大のニュース**: Google が Anthropic に **最大 $40B** (現金 + コンピュート) を投資すると発表。
これにより:
- **Gemini × Claude の技術融合** が加速する可能性 (Google Cloud上でのClaude API料金低下)
- **Google I/O 2026 (5/19)** でのGemini 4発表と組み合わせると、Anthropic製品のGoogle Cloud統合強化が期待
- **自分株式会社の ai-hub**: Claude API が Google Cloud 経由で安くなる可能性 → コスト構造改善

**脅威評価**: 🔴 (最高)  
自分株式会社は既に Claude + Gemini の両方を ai-hub で使用中 → 投資効果で API コストが下がれば純プラス。ただし Google の直接競合製品 (Workspace AI "office intern") 強化も加速。

**対応**: Win版 ai-hub で Google Cloud / Vertex AI 経由 Claude API routing を検討依頼 (新 cross-instance-pr)

---

### 🔴 Google — Workspace AI "AI office intern" 強化 (NEW)

- Google Workspace が複数の業務タスクを**自動化するAIアシスタント**として進化
- Meet / Docs / Gmail / Sheets で AI が「intern」として作業を代替
- 対象: 企業ユーザー中心 → 個人向け自分株式会社との直接競合は限定的
- ただし「AI が仕事を自動化する」という価値提案が市場に浸透する = 個人CEO OS の必要性も訴求しやすくなる

**脅威評価**: 🟠 (中-高) / 法人向け強化のため個人向け差別化は維持可能

---

### 🟠 Google — 新AI チップ発表 (NEW)

- Nvidia 対抗の新世代 AI アクセラレーターチップを Google Cloud が発表
- 自分株式会社への直接影響: なし (Supabase 使用中)
- 中期影響: Google Cloud コスト低下 → Vertex AI / Gemini API 料金低下の可能性

---

### 🔴 OpenAI (codex) — GPT-5.5 正式確認

**前回 (4/24)**: "GPT-5.5 (Spud) 2026-04-23リリース" を速報記録済み
**本日確認**: paid subscribers 向け展開 + "AI super app" への布石と位置付けが明確化

| 指標 | GPT-5.5 | 自分株式会社への影響 |
|------|---------|-------------------|
| リリース | 2026-04-23 (paid) | 週次モデル更新ペース継続 |
| 位置付け | Super App への中継モデル | ai-hub routing 再考必要 |
| Infosys提携 | エンタープライズ採用拡大 | 法人向け強化 → 個人向け差別化維持 |

---

### 🟡 DeepSeek — 新モデルプレビュー (NEW)

- frontier AIとの「ギャップ縮小」を主張する新モデルをプレビュー
- オープンソース路線継続 → ai-hub の低コスト代替 routing 候補に浮上
- 自分株式会社: 現状 DeepSeek は ai-hub 未採用。コスト観点での追加を Win版に確認依頼

**脅威評価**: 🟡 (低-中) / むしろコスト削減チャンス

---

## 全体サマリー (2026-04-25 時点)

| 指標 | 前回 (4/24) | 今回 (4/25) | 変化 |
|------|------------|------------|------|
| 最大脅威 | Natural AI Phone + Slack | **Google $40B Anthropic投資** | ↑エスカレート |
| チャンス | Evernote Free制限 + Notion課金 | 同上 + Google Workspace法人集中 | 維持 |
| 緊急対応 | Gemini Flash-Lite 廃止 (6/1) | **同上 (残36日)** | 優先度変わらず |
| I/O カウントダウン | 25日 | **24日** | -1 |

---

## 変化なし (前回スナップショット参照)

`SCOREBOARD_2026-04-24.md` に記載の以下項目は変化なし:
- notion / evernote / moneyforward / slack / chatwork / x / animaworks
- claude-code / netkeiba / openclaw / claude-cowork / jobcan / amazon
- microsoft / discord / line / facebook / liven / github

---

## 新規 cross-instance-pr 発行必要 (本日判断)

### Win版 への新依頼

1. **Google Cloud Vertex AI 経由 Claude API** routing 検討
   - Google $40B 投資 → Vertex AI 上の Claude API が安くなる可能性大
   - 現状の `ANTHROPIC_API_KEY` を Vertex AI 版に切り替える判断ポイント調査
   - 期限: I/O 2026後 (2026-05-20以降)

2. **DeepSeek 新モデル** を ai-hub experimental routing に追加検討
   - frontier gap 縮小 → コスト対効果でルーティング候補
   - 現状: ai-hub に DeepSeek 未採用 → Win版で調査依頼

---

## 次回モニタリング優先事項 (2026-04-26)

1. **Google Anthropic投資**: Vertex AI Claude API 提供詳細発表待ち
2. **DeepSeek 新モデル**: 公式発表 + ベンチマーク確認
3. **OpenAI GPT-5.5**: paid以外への展開タイムライン
4. **check-competitor-updates EF 404**: PS#5 or Win版での調査継続
5. **I/O 2026 (23日前)**: Sundar keynote preview リーク確認

---

*生成: PS版#4 S39 / 2026-04-25*
*Sources: TechCrunch, ProductHunt, Google Cloud Blog*
