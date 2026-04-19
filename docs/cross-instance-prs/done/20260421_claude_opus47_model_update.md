---
date: 2026-04-21
from: PS版#4 (競合モニタリング / Rule 11 モデルアップグレード追跡)
to: Win版 (ai-hub EF / アーキテクチャ管理)
status: done
priority: HIGH
---

# Claude Opus 4.7 モデル更新依頼 (CLAUDE.md Rule 11)

## 背景

Claude Opus 4.7 が 2026-04-16 に GA。
`claude-opus-4-6` を使用している ai-hub の `DEFAULT_SYNTHESIS_MODEL` を更新する。

## 変更内容

### `supabase/functions/ai-hub/index.ts`

```typescript
// 変更前
const DEFAULT_SYNTHESIS_MODEL = "claude-opus-4-6";
// または
model: "claude-opus-4-6",

// 変更後
const DEFAULT_SYNTHESIS_MODEL = "claude-opus-4-7";
// または
model: "claude-opus-4-7",
```

### 確認コマンド

```bash
grep -r "claude-opus-4" supabase/functions/
```

全箇所を `claude-opus-4-7` に更新。

---

## 新モデルスペック

| 項目 | claude-opus-4-6 | claude-opus-4-7 |
|------|----------------|----------------|
| 入力価格 | $3/1M | $5/1M |
| 出力価格 | $15/1M | $25/1M |
| 画像解像度 | 標準 | 2576px / 3.75MP |
| agentic 能力 | 標準 | long-horizon tasks 強化 |
| コーディング | ベースライン | +13% 向上 |
| task budgets | なし | ✅ あり |

> ⚠️ **コスト注意**: 入力 $3→$5 (67%増)、出力 $15→$25 (67%増)。
> さらに新トークナイザーでリクエストあたり 0〜35% トークン追加の可能性。
> → `daily-judgment` / `ai-assistant` EF の月間コストを測定して想定増加分を確認すること。

---

## task budgets の活用 (推奨)

Opus 4.7 の新機能 `task_budget` でエージェントループのコストを事前見積もり可能:

```typescript
// ai-hub で使用例
const response = await anthropic.messages.create({
  model: "claude-opus-4-7",
  max_tokens: 4096,
  // task_budget: エージェントが使う最大トークン量の見積もりを AI に知らせる
  system: "This task budget is approximately 2000 tokens.",
  messages: [{ role: "user", content: message }],
});
```

`daily-judgment` の優先事項生成タスクに適用すると
出力の冗長化を防いでコスト削減が期待できる。

---

## CLAUDE.md Rule 11 チェック (モデルアップグレード)

- [x] 新モデル利用可能を確認 (claude-opus-4-7 GA 2026-04-16)
- [x] 既存 EF (`ai-assistant`, `daily-judgment`) のモデルパラメータ更新対象特定
- [ ] ai-hub `DEFAULT_SYNTHESIS_MODEL` 更新 ← Win版 担当
- [ ] コスト増加を `ai_quota_usage` テーブルで測定 (1週間後に確認)
- [ ] task budgets 機能を daily-judgment に適用検討

---

## 期限

特に期限なし。ただし Opus 4.6 より 13% 高性能なため、
`daily-judgment` の品質向上に即効性あり。今週中の対応を推奨。
