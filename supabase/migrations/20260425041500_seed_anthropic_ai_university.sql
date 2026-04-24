-- Session PS#4-S38: AI大学 170→172社化 — Anthropic (Claude 4.x) 追加
-- Dario Amodei・Daniela Amodei が 2021 年に OpenAI から独立して創業した AI 安全性研究企業。
-- Constitutional AI (CAI) + Responsible Scaling Policy (RSP) で安全性を体系化。
-- Amazon $4B・Google $2B 投資。評価額 $18.4B (2024-09)。ARR $2B+ (2025)。
-- Claude 4.x ファミリー (Haiku 4.5 / Sonnet 4.6 / Opus 4.7) が最新。
-- このプロジェクト自体が claude-sonnet-4-6 + claude-opus-4-7 を本番採用。
-- Step 0: 9/9 (AI 安全性リーダー / $7.3B 累計 / Claude 4 / Constitutional AI / Amazon 統合)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'anthropic',
  'overview',
  'Anthropic — Constitutional AIで安全性を体系化したAI研究企業',
  $md$
# Anthropic — 安全なAIを最優先する研究企業

**Dario Amodei** (CEO) と **Daniela Amodei** (President) が 2021 年に OpenAI から独立して創業。
「AI がもたらす壊滅的なリスクを防ぐには、安全研究をしながら最先端モデルを自分たちで作るしかない」という信念から出発した。

## 企業概要

| 項目 | 内容 |
| :--- | :--- |
| **創業** | 2021 年 / Dario Amodei・Daniela Amodei (元 OpenAI VP of Research / VP of Research) |
| **本社** | サンフランシスコ |
| **評価額** | $18.4B (2024-09 資金調達ラウンド) |
| **累計調達** | $7.3B+ (Amazon $4B + Google $2B + 複数ラウンド) |
| **ARR** | $2B+ (2025 年推定) |
| **主な投資家** | Amazon・Google・Spark Capital・Salesforce Ventures |

## Constitutional AI (CAI) — Anthropic の核心技術

多くのAI企業が「人間のフィードバックで直接調整 (RLHF)」するのに対し、
Anthropic は **Constitutional AI** という独自手法を採用する。

1. **原則リスト (Constitution)** を先に明文化する (有害性回避・誠実性・無害性など)
2. **AI が AI を評価**: AIが自分の出力を原則に照らして批判・改訂する (RLAIF)
3. 人間フィードバック依存を減らし、**スケーラブルな安全性評価**を実現

この手法により、「人間が全回答を監視できないほど賢いAIが来たとき」でも
安全性を維持できるフレームワークを構築している。

## Responsible Scaling Policy (RSP)

モデルが一定の危険能力に達する前に **開発を一時停止する自己課税ルール**。
AI Safety Level (ASL) 評価で ASL-3 (大量破壊兵器への助力リスク) に到達したモデルは、
対策が整うまでリリースしない。競合が先行してもルールを守ることを公約している。

## モデルスペック (Model Spec)

Claude の価値観・行動原則を記した **公開ドキュメント**。
「正直 (Honest)」「無害 (Harmless)」「有益 (Helpful)」の優先順位を明示。
HHH 原則とも呼ばれ、AI業界で広く参照されている。
$md$,
  'https://www.anthropic.com/',
  '2026-04-24',
  1
),

(
  'anthropic',
  'models',
  'Claude 4.x — Haiku/Sonnet/Opus の最新ファミリー完全ガイド',
  $md$
## Claude モデルファミリー (2026-04 時点)

### Claude 4.x ファミリー (最新世代)

| モデル | モデルID | 特徴 | Input ($/1M) | Output ($/1M) | Context |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Claude Haiku 4.5** | `claude-haiku-4-5-20251001` | 超高速・軽量 / コスト最適 | $0.80 | $4.00 | 200K |
| **Claude Sonnet 4.6** | `claude-sonnet-4-6` | バランス最良・エージェント最適 | $3.00 | $15.00 | 200K |
| **Claude Opus 4.7** | `claude-opus-4-7` | 最高性能・複雑推論 | $15.00 | $75.00 | 200K |

> **自分株式会社での採用**: claude-sonnet-4-6 (ai-assistant Balthasar/Synthesis) +
> claude-opus-4-7 extended_thinking (深い分析タスク)

### Claude 3.7 / 3.5 ファミリー (前世代・API 互換維持)

| モデル | 特徴 |
| :--- | :--- |
| Claude 3.7 Sonnet | 初のハイブリッド推論モデル (思考チェーン可視化) |
| Claude 3.5 Sonnet (Oct 2024) | Computer Use 機能搭載 |
| Claude 3.5 Haiku | 高速・安価な実用モデル |
| Claude 3 Opus | 高性能 (前々世代) |

### Extended Thinking (深い思考モード)

Claude 4.x では `extended_thinking` パラメータで **思考チェーン**を有効化できる。
複雑な数学・コーディング・論理推論で大幅に精度向上。
思考トークンは billing 対象だが、より確実な回答が得られる。

```python
import anthropic

client = anthropic.Anthropic(api_key="sk-ant-...")

response = client.messages.create(
    model="claude-opus-4-7",
    max_tokens=16000,
    thinking={
        "type": "enabled",
        "budget_tokens": 10000  # 思考に使うトークン上限
    },
    messages=[{"role": "user", "content": "微分方程式を解いて"}]
)
```

### ベンチマーク比較 (Claude Sonnet 4.6)

| ベンチマーク | Claude Sonnet 4.6 | GPT-5.5 | Grok 4 Heavy |
| :--- | :--- | :--- | :--- |
| MMLU | **91.5%** | 90%+ | 92%+ |
| HumanEval | **93%** | 95%+ | — |
| GPQA | **84%** | 78% | 88.4% |
| SWE-Bench Verified | **70%+** | 58.6% | — |

Claude は特に **長文理解・コーディング・安全性** に強みがある。
$md$,
  'https://www.anthropic.com/claude',
  '2026-04-24',
  2
),

(
  'anthropic',
  'api',
  'Anthropic API 入門 — Messages API / Tool Use / Computer Use',
  $md$
## Anthropic API の基本

| 項目 | 内容 |
| :--- | :--- |
| **エンドポイント** | `https://api.anthropic.com/v1` |
| **SDK** | Python (`anthropic`) / TypeScript (`@anthropic-ai/sdk`) |
| **認証** | `x-api-key: sk-ant-api03-...` ヘッダー |
| **最大コンテキスト** | 200K トークン |
| **Prompt Caching** | 同一プレフィクスを最大 90% 割引でキャッシュ |

## Messages API (基本)

```python
import anthropic

client = anthropic.Anthropic(api_key="sk-ant-...")

message = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system="あなたは自分株式会社のAIアシスタントです。",
    messages=[
        {"role": "user", "content": "今日の優先タスクを教えて"}
    ]
)

print(message.content[0].text)
print(f"入力トークン: {message.usage.input_tokens}")
print(f"出力トークン: {message.usage.output_tokens}")
```

## Tool Use (関数呼び出し)

```python
tools = [
    {
        "name": "get_user_tasks",
        "description": "ユーザーのタスク一覧を取得する",
        "input_schema": {
            "type": "object",
            "properties": {
                "status": {
                    "type": "string",
                    "enum": ["pending", "in_progress", "done"]
                }
            },
            "required": ["status"]
        }
    }
]

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    tools=tools,
    messages=[{"role": "user", "content": "今日の未完了タスクを教えて"}]
)

# tool_use ブロックを解析してツール実行
if response.stop_reason == "tool_use":
    tool_call = next(b for b in response.content if b.type == "tool_use")
    tool_name = tool_call.name
    tool_input = tool_call.input
```

## Vision (画像入力)

```python
import base64

with open("screenshot.png", "rb") as f:
    image_data = base64.standard_b64encode(f.read()).decode("utf-8")

response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[{
        "role": "user",
        "content": [
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/png",
                    "data": image_data
                }
            },
            {"type": "text", "text": "このスクリーンショットのUIを改善する提案をして"}
        ]
    }]
)
```

## Prompt Caching (コスト最適化)

同一のシステムプロンプトやドキュメントを繰り返し使う場合:

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": "長いシステムプロンプト...",
            "cache_control": {"type": "ephemeral"}  # キャッシュ指定
        }
    ],
    messages=[{"role": "user", "content": "質問"}]
)
# 2回目以降は cache_read_input_tokens で 90% オフ
```

## アクセス方法

1. [console.anthropic.com](https://console.anthropic.com) でアカウント作成
2. API キーを発行 (`sk-ant-api03-...`)
3. `pip install anthropic` でインストール
4. 環境変数: `export ANTHROPIC_API_KEY=sk-ant-...`
$md$,
  'https://docs.anthropic.com/en/api/getting-started',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
