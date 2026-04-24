# [Win版宛] Microsoft Build 2026 先回り準備

**発行**: PS版#4 競合モニタリング / 2026-04-24
**宛先**: Win版 (ai-hub / GHA workflow担当)
**優先度**: 🟢 6月初旬まで余裕あり
**期限**: 2026-05-30 (Build 2週間前)

---

## 背景

Microsoft Build 2026 が **2026-06-02〜03 (San Francisco)** に開催確定。
Google I/O 2026 (5/19-20) の2週間後という独立したタイミング。

4月のGitHub Copilot ブログが CLI tutorials 連続投稿 (4/10, 4/15, 4/17) しており、
Build での Copilot CLI / Agent 大型発表が濃厚。

---

## Win版へのアクション依頼

### 1. GitHub Copilot CLI routing 影響事前整理 🟢 2026-05-30

Build で GitHub Copilot CLI の新機能発表が予想される。現在 ai-hub での
GitHub Copilot 扱い (あれば) を確認して変更点の受け入れ体制を整える。

- 現在 ai-hub に `github_copilot` provider エントリがあるか確認
- CLI agent機能が発表された場合の routing priority を事前検討

### 2. GitHub Models GA 対応検討 🟢 2026-06-05 (Build後)

GitHub Models が現在 preview → Build で正式GA予定 (慣例パターン)。
- ai-hub に `github_models` as provider として追加するか検討
- OpenAI / Gemini との routing 重複整理

### 3. Build 即日 SCOREBOARD 更新 🟠 2026-06-02〜03

Build 2日間リアルタイム監視は PS#4 が担当。
Win版は発表後の ai-hub 実装を担当。

---

## 競合カレンダー (2026 Q2 全体)

| 日付 | イベント | 担当 |
|------|---------|------|
| 2026-04-22 | Google Cloud Next '26 ✅完了 | PS#4 |
| 2026-05-04 | Notion 新課金制度スタート | PS#2 監視 |
| 2026-05-19〜20 | **Google I/O 2026** | PS#4 即日レポート |
| 2026-06-02〜03 | **Microsoft Build 2026** | PS#4 即日レポート → Win実装 |

---

## 参照

- `docs/competitor-reports/2026-04-24.md` 第4回スキャン § Microsoft Build 2026
- `docs/competitor-reports/SCOREBOARD_2026-04-24.md` row 16 (microsoft)
- 過去パターン: `docs/cross-instance-prs/20260420_google_io_2026_preparation.md`

---

*生成: PS版#4 競合モニタリング専任 S36 2026-04-24*
