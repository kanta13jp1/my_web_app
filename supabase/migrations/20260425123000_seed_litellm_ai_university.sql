-- Session PS#3-S45: AI大学 190社化 — LiteLLM 追加
-- BerriAI が開発する 100+ LLM 統合 API プロキシ。OpenAI 形式で全プロバイダーを呼び出せる。
-- GitHub 15k+ Stars / Apache 2.0 / Docker / Python / エンタープライズ利用多数。
-- Claude / Gemini / Mistral / Ollama など全社を同一インターフェースで切り替え可能。
-- Step 0: 8/9 (マルチ LLM 統合 / OpenAI SDK 完全互換 / フォールバック / 15k+ Stars / OSS)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'litellm',
  'overview',
  'LiteLLM — 100+ LLM を1つの OpenAI 互換 API で統合するプロキシ',
  $md$
# LiteLLM — Call 100+ LLMs Using OpenAI Format

**BerriAI** が開発するオープンソースの LLM プロキシ・SDK。

`openai` / `anthropic` / `google` / `cohere` / `mistral` / `ollama` など
**100+ の LLM プロバイダー**を OpenAI SDK 互換の統一形式で呼び出せる。

GitHub Stars **15,000+** / Apache 2.0 ライセンス。

## 核心機能

| 機能 | 説明 |
| :--- | :--- |
| **統一 API** | 全プロバイダーを `openai.chat.completions.create()` 形式で呼び出し |
| **フォールバック** | プライマリ LLM が失敗したら自動で代替 LLM に切替 |
| **ロードバランシング** | 複数の同一モデルにトラフィックを分散 |
| **コスト追跡** | リクエストごとのコスト計算・ログ記録 |
| **レート制限** | per-user / per-team のレート制限管理 |
| **キャッシュ** | Redis / in-memory キャッシュで同一リクエストをコスト削減 |

## 2 つの使い方

### 1. Python SDK (最小構成)

```python
from litellm import completion

# Claude
response = completion(
    model="anthropic/claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Hello"}]
)

# Gemini (同じコード、model 名を変えるだけ)
response = completion(
    model="gemini/gemini-2.5-flash",
    messages=[{"role": "user", "content": "Hello"}]
)
```

### 2. OpenAI 互換プロキシサーバー (エンタープライズ向け)

```bash
# Docker でプロキシ起動
docker run -p 4000:4000 \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  -e OPENAI_API_KEY=sk-... \
  ghcr.io/berriai/litellm:main \
  --model anthropic/claude-sonnet-4-6 --model openai/gpt-4o
```

既存の OpenAI SDK を URL 変更だけで LiteLLM 経由に切替可能。

## 競合プロバイダーとの違い

| 比較項目 | LiteLLM | OpenRouter | Portkey |
| :--- | :--- | :--- | :--- |
| セルフホスト | **可能** | 不可 | 有料プランのみ |
| 価格 | **無料 (OSS)** | マークアップあり | プランあり |
| フォールバック | **豊富** | 基本的 | あり |
| コスト追跡 | **詳細** | なし | あり |
| カスタムモデル | **可能** | 限定的 | 限定的 |
$md$,
  'https://docs.litellm.ai/',
  '2026-04-25',
  1
),

(
  'litellm',
  'api',
  'LiteLLM 入門 — インストール・フォールバック・ロードバランシング・コスト追跡',
  $md$
## インストール

```bash
pip install litellm

# プロキシサーバーも使う場合
pip install 'litellm[proxy]'
```

---

## 基本的な使い方 — モデル切替

```python
from litellm import completion

# モデル名のフォーマット: "プロバイダー/モデル名"
models = {
    "gpt4o": "openai/gpt-4o",
    "claude": "anthropic/claude-sonnet-4-6",
    "gemini": "gemini/gemini-2.5-flash",
    "mistral": "mistral/mistral-large-latest",
    "ollama": "ollama/llama3.2",  # ローカル
}

def chat(prompt: str, model_key: str = "claude"):
    response = completion(
        model=models[model_key],
        messages=[{"role": "user", "content": prompt}]
    )
    return response.choices[0].message.content
```

---

## フォールバック設定

```python
from litellm import completion

response = completion(
    model="anthropic/claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Hello"}],
    fallbacks=[
        "openai/gpt-4o",              # 1st fallback
        "gemini/gemini-2.5-flash",    # 2nd fallback
        "ollama/llama3.2",            # 最終フォールバック (ローカル)
    ],
    num_retries=3,
)
```

---

## ロードバランシング

```python
import litellm

# 複数デプロイメントにトラフィックを分散
litellm.set_verbose = False
response = litellm.completion(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello"}],
    api_base="https://your-litellm-proxy.com",  # プロキシ経由
)
```

---

## コスト追跡

```python
from litellm import completion

response = completion(
    model="anthropic/claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Hello"}]
)

# コスト情報を取得
print(f"入力トークン: {response.usage.prompt_tokens}")
print(f"出力トークン: {response.usage.completion_tokens}")
print(f"推定コスト: ${response._hidden_params.get('response_cost', 0):.6f}")
```

---

## プロキシ設定 (config.yaml)

```yaml
model_list:
  - model_name: claude-primary
    litellm_params:
      model: anthropic/claude-sonnet-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

  - model_name: gpt-fallback
    litellm_params:
      model: openai/gpt-4o
      api_key: os.environ/OPENAI_API_KEY

router_settings:
  routing_strategy: least-busy
  fallbacks:
    - claude-primary:
        - gpt-fallback

litellm_settings:
  success_callback: ["langfuse"]  # 監視連携
  cache: true
  cache_params:
    type: redis
    host: localhost
    port: 6379
```

---

## Supabase Edge Function との統合例

```typescript
// Deno Edge Function �� LiteLLM プロキシを経由
const response = await fetch("https://your-litellm.railway.app/chat/completions", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${Deno.env.get("LITELLM_API_KEY")}`,
  },
  body: JSON.stringify({
    model: "claude-sonnet-4-6",  // LiteLLM が内部でルーティング
    messages: [{ role: "user", content: prompt }],
  }),
});
```
$md$,
  'https://docs.litellm.ai/docs/proxy/quick_start',
  '2026-04-25',
  2
),

(
  'litellm',
  'models',
  'LiteLLM 本番運用 — キャッシュ・監視・セキュリティ・Railway デプロイ',
  $md$
## Redis キャッシュで重複リクエストを節約

```python
import litellm

# Redis キャッシュを有効化
litellm.cache = litellm.Cache(
    type="redis",
    host="localhost",
    port=6379,
    password="your-password"
)

# 同一プロンプトは 2 回目以降キャッシュから返す
response1 = litellm.completion(model="openai/gpt-4o", messages=[...])
response2 = litellm.completion(model="openai/gpt-4o", messages=[...])
# response2 はキャッシュヒット → コスト 0
```

---

## Langfuse / Helicone との監視統合

```python
import litellm

litellm.success_callback = ["langfuse"]
litellm.failure_callback = ["langfuse"]

os.environ["LANGFUSE_PUBLIC_KEY"] = "pk-..."
os.environ["LANGFUSE_SECRET_KEY"] = "sk-..."

response = litellm.completion(
    model="anthropic/claude-sonnet-4-6",
    messages=[{"role": "user", "content": "Hello"}],
    metadata={"user_id": "user_123", "session_id": "sess_456"}
)
# Langfuse ダッシュボードにコスト・レイテンシーが自動記録
```

---

## Railway でのデプロイ (推奨)

```bash
# Railway CLI
railway login
railway new
railway add --service litellm-proxy
railway variables set ANTHROPIC_API_KEY=sk-ant-...
railway variables set OPENAI_API_KEY=sk-...
railway up
# → https://your-app.railway.app に LiteLLM プロキシが立ち上がる
```

---

## セキュリティ設定

```yaml
# config.yaml — API キーベースのアクセス制御
general_settings:
  master_key: sk-1234   # 管理者キー
  litellm_key_header_name: "X-LiteLLM-Key"

# チーム別キーの発行
litellm_settings:
  # チームごとに予算上限を設定
  team_budget_log: true
```

---

## 実装チェックリスト

- [ ] `pip install litellm` でインストール
- [ ] 使用する LLM の API キーを環境変数に設定
- [ ] `fallbacks` でフォールバックリストを設定
- [ ] Redis でキャッシュを有効化 (本番推奨)
- [ ] Langfuse/Helicone でコスト監視を設定
- [ ] Railway / Fly.io でプロキシをデプロイ
$md$,
  'https://docs.litellm.ai/docs/proxy/deploy',
  '2026-04-25',
  3
)

ON CONFLICT DO NOTHING;
