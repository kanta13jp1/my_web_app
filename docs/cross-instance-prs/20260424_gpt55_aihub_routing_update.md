# [Win版宛] GPT-5.5 (Spud) リリース — ai-hub routing更新検討

**発行**: PS版#4 競合モニタリング / 2026-04-24
**宛先**: Win版 (ai-hub / Edge Function担当)
**優先度**: 🟡 今月中
**期限**: 2026-05-15

---

## 背景

OpenAI が GPT-5.5 (コードネーム "Spud") を 2026-04-23 に paid subscribers 向けにリリース。
GPT-5.4 からわずか **6週間** で次バージョン投入 = モデル更新ペースが月次→週次レベルに加速中。

### OpenAI モデル系譜 (2026-04時点)

| モデル | リリース | 特徴 |
|--------|---------|------|
| GPT-5.4 | 2026-03-05 | current major |
| GPT-5.4 mini | 4月ロールアウト中 | 軽量・Free/Go向けフォールバック |
| **GPT-5.5 (Spud)** | **2026-04-23** | 最新・paid subscribers |
| GPT-5.3-Codex | 既存 | agentic coding特化 |

---

## Win版へのアクション依頼

### 1. ai-hub の OpenAI モデル列確認

現在 `ai-hub` EF (または provider.chat action) に登録している OpenAI モデルが最新か確認:
- `gpt-5.4` → `gpt-5.5` への更新検討
- `gpt-5.4-mini` の軽量ルート用登録状況確認

### 2. routing cost見直し

GPT-5.5のAPI価格が公開されたら:
- output-bound タスクのコスト比較表を更新
- Gemini FL ($1.50/M output) vs GPT-5.5 (未確認) vs Nova 2 Lite ($2.50/M output) の3社比較

### 3. 競合差別化への影響

GPT-5.5で自分株式会社の **差別化軸7 (vendor分散)** がより重要に:
- OpenAI が週次更新で競合他社のmodel更新に追われる構造が続く
- 自分株式会社 = OpenAI依存なし → 複数vendor分散でmajor updateへの露出を分散できる

### 期待する成果物

- ai-hub model登録の更新commit (or 「現状GPT-5.5 API未対応のため保留」報告)
- routing cost表の price列更新

---

*参照: `docs/competitor-reports/SCOREBOARD_2026-04-24.md` #9 codex行*
