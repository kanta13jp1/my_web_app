-- PS#3 S109: AI大学 312→313社化 — LiteLLM (100+ LLM統合プロキシ/OpenAI互換/ロードバランシング)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'litellm', 'overview',
  'LiteLLM — 100+ LLMを統一OpenAI互換APIで呼び出すプロキシ・ロードバランシング (GitHub 15k+ / 9/9)',
  $$## LiteLLM とは

**LiteLLM** は **100以上の LLM プロバイダーを単一の OpenAI 互換 API で呼び出せるプロキシ・ライブラリ**。GitHub 15,000+ スター。`openai.ChatCompletion.create()` の呼び出し1行を変えるだけで、**Anthropic Claude / Google Gemini / AWS Bedrock / Azure OpenAI / Cohere / HuggingFace** などどのプロバイダーにも切り替えられる。

**LiteLLM Proxy Server** を起動すると、複数のプロバイダーへのロードバランシング・フォールバック・コスト追跡・レート制限・キャッシングを一元管理できる。

## 対応プロバイダー (主要100+)

```
OpenAI:         gpt-4o / gpt-4o-mini / o1 / o3
Anthropic:      claude-opus-4-7 / claude-sonnet-4-6 / claude-haiku-4-5
Google:         gemini-2.0-flash / gemini-1.5-pro / gemini-1.5-flash
AWS Bedrock:    amazon.nova-pro / amazon.titan-text
Azure OpenAI:   azure/gpt-4o / azure/gpt-4-turbo
Cohere:         command-r-plus / command-r
Mistral:        mistral-large / mistral-medium
HuggingFace:    HuggingFace/... (任意モデル)
Ollama:         ollama/llama3.2 / ollama/mistral (ローカル)
vLLM:           hosted_vllm/... (セルフホスト)
Groq:           groq/llama-3.1-70b-versatile (超高速)
Together AI:    together_ai/...
Replicate:      replicate/...
Vertex AI:      vertex_ai/...
...100以上のプロバイダー
```

## LiteLLM の主要機能

```
ロードバランシング:
  ・同一モデルを複数エンドポイントで分散 (RPM/TPM 制限回避)
  ・ラウンドロビン / 最小レイテンシ / コスト最小化

フォールバック:
  ・プライマリ失敗時に自動でセカンダリへ切り替え
  ・例: Claude API 障害 → Gemini に自動フォールバック

コスト管理:
  ・全リクエストのコスト・トークン数を自動追跡
  ・プロバイダー別・モデル別・チーム別のコストレポート
  ・予算上限設定 (budget_manager)

キャッシング:
  ・Redis / S3 / In-Memory キャッシュ対応
  ・同一プロンプトのレスポンスを再利用してコスト削減

レート制限:
  ・チーム別・ユーザー別の RPM/TPM 制限
  ・API キーごとのアクセス制御
```

## 自分株式会社での活用

| シーン | 活用方法 | 期待効果 |
|--------|----------|---------|
| **マルチLLM管理** | Claude/Gemini/GPT-4oを1つのAPIで管理 | プロバイダー切り替えが1行変更のみ |
| **コスト最適化** | 開発はHaiku/本番はSonnet/重要タスクはOpus | タスク重要度別コスト最適化 |
| **フォールバック** | Claude障害時にGeminiへ自動切り替え | 99.9%可用性を維持 |$$,
  NULL, NULL, 1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'litellm', 'api',
  'LiteLLM 実践 — Python SDK/Proxy Server/設定YAML/ロードバランシング/フォールバック/コスト追跡/キャッシング',
  $$## インストール

```bash
pip install litellm

# Proxy Server 用
pip install 'litellm[proxy]'
```

## Python SDK — 基本使用法

```python
import litellm

# Anthropic Claude (OpenAI 互換インターフェース)
response = litellm.completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "競馬の天皇賞春の歴史を教えて"}],
)
print(response.choices[0].message.content)

# Google Gemini (モデル名だけ変更)
response = litellm.completion(
    model="gemini/gemini-2.0-flash",
    messages=[{"role": "user", "content": "競馬の天皇賞春の歴史を教えて"}],
)
print(response.choices[0].message.content)

# OpenAI (モデル名だけ変更)
response = litellm.completion(
    model="gpt-4o-mini",
    messages=[{"role": "user", "content": "競馬の天皇賞春の歴史を教えて"}],
)
print(response.choices[0].message.content)
```

## 非同期 + ストリーミング

```python
import litellm
import asyncio

async def stream_response():
    response = await litellm.acompletion(
        model="claude-haiku-4-5",
        messages=[{"role": "user", "content": "今週のG1レースの見どころを教えて"}],
        stream=True,
    )
    async for chunk in response:
        content = chunk.choices[0].delta.content
        if content:
            print(content, end="", flush=True)
    print()

asyncio.run(stream_response())
```

## フォールバック設定

```python
import litellm

# モデルリストでフォールバックを定義
response = litellm.completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "競馬予想を教えて"}],
    fallbacks=[
        "gemini/gemini-1.5-pro",   # Claude 失敗時
        "gpt-4o-mini",              # Gemini も失敗時
    ],
    num_retries=2,
    timeout=30,
)
print(response.choices[0].message.content)
```

## コスト追跡

```python
import litellm

# コールバックを設定してコストを追跡
def log_cost(kwargs, completion_response, start_time, end_time):
    cost = litellm.completion_cost(completion_response)
    model = kwargs.get("model")
    tokens = completion_response.usage.total_tokens
    print(f"Model: {model}, Tokens: {tokens}, Cost: ${cost:.6f}")

litellm.success_callback = [log_cost]

response = litellm.completion(
    model="claude-sonnet-4-6",
    messages=[{"role": "user", "content": "今日の競馬予想"}],
)
# → Model: claude-sonnet-4-6, Tokens: 150, Cost: $0.000450
```

## Proxy Server 設定 (config.yaml)

```yaml
# litellm_config.yaml
model_list:
  # Claude 系
  - model_name: claude-sonnet       # エイリアス名 (API で指定)
    litellm_params:
      model: claude-sonnet-4-6
      api_key: os.environ/ANTHROPIC_API_KEY

  # 同じエイリアスで複数エンドポイント → ロードバランシング
  - model_name: fast-llm
    litellm_params:
      model: groq/llama-3.1-70b-versatile
      api_key: os.environ/GROQ_API_KEY
  - model_name: fast-llm
    litellm_params:
      model: gemini/gemini-2.0-flash
      api_key: os.environ/GEMINI_API_KEY

  # Ollama ローカル
  - model_name: local-llama
    litellm_params:
      model: ollama/llama3.2
      api_base: http://localhost:11434

litellm_settings:
  # フォールバック設定
  fallbacks:
    - {"claude-sonnet": ["gemini/gemini-1.5-pro", "gpt-4o-mini"]}

  # Redis キャッシング
  cache: true
  cache_params:
    type: redis
    host: localhost
    port: 6379

router_settings:
  routing_strategy: least-busy     # 最少負荷ルーティング
  num_retries: 3
  timeout: 30
  retry_after: 5

general_settings:
  # チーム別予算
  budget_duration: 1d
  max_budget: 10.0                  # 1日$10上限
```

## Proxy Server 起動 & 接続

```bash
# Proxy Server を起動
litellm --config litellm_config.yaml --port 4000

# → http://localhost:4000/v1 (OpenAI 互換)
```

```python
from openai import OpenAI

# LiteLLM Proxy に接続 (OpenAI SDK そのまま)
client = OpenAI(
    base_url="http://localhost:4000",
    api_key="any-key",  # Proxy が API キーを管理
)

# エイリアス名で呼び出し (実際のモデルは config.yaml が決定)
response = client.chat.completions.create(
    model="claude-sonnet",
    messages=[{"role": "user", "content": "今週のG1予想を教えて"}],
)
print(response.choices[0].message.content)

# fast-llm → Groq または Gemini にロードバランシング
response = client.chat.completions.create(
    model="fast-llm",
    messages=[{"role": "user", "content": "簡単な質問です"}],
)
```

## Supabase Edge Function での活用

```typescript
// supabase/functions/ai-assistant/index.ts
// LiteLLM Proxy を経由してマルチLLMを管理

const LITELLM_URL = Deno.env.get("LITELLM_URL") || "http://litellm-proxy:4000";
const LITELLM_KEY = Deno.env.get("LITELLM_API_KEY") || "";

async function callLLM(prompt: string, tier: "fast" | "smart" | "economy") {
  const modelMap = {
    fast: "fast-llm",        // Groq/Gemini Flash ロードバランシング
    smart: "claude-sonnet",  // Claude Sonnet
    economy: "local-llama",  // Ollama ローカル
  };

  const res = await fetch(`${LITELLM_URL}/v1/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${LITELLM_KEY}`,
    },
    body: JSON.stringify({
      model: modelMap[tier],
      messages: [{ role: "user", content: prompt }],
      max_tokens: 500,
    }),
  });

  const data = await res.json();
  return data.choices[0].message.content;
}
```$$,
  NULL, NULL, 2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 312→313社化: LiteLLM 追加',
  'PS#3 S109。LiteLLM (100+ LLMプロバイダー統合/OpenAI互換プロキシ/ロードバランシング/フォールバック/コスト追跡/Redisキャッシング/チーム別予算管理/GitHub 15k+/9/9) を ai_university_content に追加。',
  '2026-04-29'
)
ON CONFLICT DO NOTHING;
