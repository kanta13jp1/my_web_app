---
date: 2026-04-20
from: PS版#4 (競合モニタリング / Rule 11 モデルアップグレード追跡)
to: Win版 (EF アーキテクチャ / ai-hub 管理)
status: pending
priority: HIGH
deadline: 2026-06-01 (Gemini 2.0 Flash-Lite sunset)
---

# Gemini 3.1 Flash-Lite 移行依頼 — June 1 sunset 前に必須

## 背景

**Gemini 2.0 Flash-Lite は 2026年6月1日に廃止 (sunset)**。
`ai-hub` / `ai-university-update` / `competitor-monitoring` EF で使用中のモデルを
`gemini-3.1-flash-lite-preview` に移行しないと 6月以降に呼び出しエラーが発生する。

## 新モデルスペック

| 項目 | 値 |
|------|-----|
| **モデル ID** | `gemini-3.1-flash-lite-preview` |
| **入力価格** | $0.25 / 1M tokens |
| **出力価格** | $1.50 / 1M tokens |
| **コンテキスト** | 1,048,576 tokens (1M) |
| **最大出力** | 65,536 tokens |
| **ステータス** | Preview (本番利用可) |
| **Sunset 対象** | Gemini 2.0 Flash-Lite → 2026-06-01 廃止 |

**コスト比較** (入力のみ):
- 旧: Gemini 2.0 Flash-Lite = $0.075/1M → 新: $0.25/1M (入力は値上がり)
- 旧: Gemini 2.0 Flash-Lite output = $0.30/1M → 新: $1.50/1M (出力は5倍)

> ⚠️ 注意: コスト削減ではなく **強制移行** (廃止対応)。
> 速度 2.5x 向上・コンテキスト拡大が主なメリット。
> バッチ処理では出力量が少ないため実質コスト増は軽微。

---

## 移行対象 EF

### 優先度 A: ai-hub の PROVIDER_CONFIGS

`supabase/functions/ai-hub/index.ts` の Gemini エントリを更新:

```typescript
// 変更前
"gemini": {
  model: "gemini-2.0-flash-lite",
  // ...
}

// 変更後
"gemini": {
  model: "gemini-3.1-flash-lite-preview",
  // ...
}
```

### 優先度 B: ai-university-update.yml

`.github/workflows/ai-university-update.yml` の gemini モデル指定を確認・更新:

```yaml
# 変更前
GEMINI_MODEL: gemini-2.0-flash-lite

# 変更後
GEMINI_MODEL: gemini-3.1-flash-lite-preview
```

### 優先度 C: Vertex AI 利用の EF があれば同様に更新

`grep -r "gemini-2.0-flash-lite" supabase/functions/` で全箇所確認してから一括置換。

---

## 実施手順

```bash
# 1. 現在の使用箇所を全確認
grep -r "gemini-2.0-flash-lite" supabase/functions/ .github/workflows/

# 2. 一括置換
find supabase/functions/ .github/workflows/ -type f \
  -exec sed -i 's/gemini-2.0-flash-lite/gemini-3.1-flash-lite-preview/g' {} +

# 3. deno lint 確認 (EF)
deno lint supabase/functions/ai-hub/index.ts

# 4. commit
git add supabase/functions/ .github/workflows/
git commit -m "feat: Gemini 3.1 Flash-Lite Preview 移行 (2.0 Flash-Lite June 1 sunset対応)"
```

---

## テスト方法

移行後、以下で動作確認:

```bash
# ai-hub gemini 呼び出しテスト
curl -X POST \
  "https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/ai-hub" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"action":"provider.chat","provider":"gemini","message":"test"}'
```

レスポンスの `model` フィールドが `gemini-3.1-flash-lite-preview` であることを確認。

---

## 期限

**2026-06-01 必須** (Gemini 2.0 Flash-Lite 廃止日)。
5月中に対応推奨 (余裕を持って動作確認期間を確保)。
