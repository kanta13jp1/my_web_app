-- PS#3 S73: AI大学 240→241社化 — LM Studio 追加
-- LM Studio: ローカルLLM実行GUI / llama.cpp バックエンド / GGUF形式 / OpenAI互換API / 完全プライバシー保護

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lmstudio',
  'overview',
  'LM Studio — ローカルLLM実行GUI (llama.cpp / GGUF / OpenAI互換API / プライバシー完全保護)',
  $$## LM Studio — ローカルLLM実行プラットフォーム

**カテゴリ**: Local LLM / On-Device AI / Developer Tools / Privacy-First AI
**開発元**: LM Studio (lmstudio.ai)
**設立**: 2023年
**対応OS**: Windows / macOS (Apple Silicon + Intel) / Linux
**バックエンド**: llama.cpp (C++実装のLLM推論エンジン)
**対応形式**: GGUF (主流) / GGML (旧形式)
**価格**: 無料 (個人・商用利用OK)
**評価**: 9/9

### 概要
LM Studio は **「ローカルPCでLLMを簡単に動かす」** ことを目的としたGUIアプリケーション。2023年に登場して以来、ローカルAI界のデファクトスタンダードとなった。特に**プライバシーが重要な業務**・**オフライン環境**・**APIコスト削減**を目的とする開発者・企業に急速に普及している。

**日本での人気**: Zenn・Qiita・Xでの解説記事が多く、日本語コミュニティも活発。中小企業での社内AI構築に多く採用。

### 主な特徴

**1. モデルライブラリ内蔵**
- Hugging Face から GGUF モデルを GUI で検索・ダウンロード
- 人気モデル: Llama 3 (Meta) / Mistral / Phi-3 (Microsoft) / Gemma (Google) / DeepSeek / Qwen2
- 量子化レベル選択: Q4_K_M (バランス) / Q8_0 (高精度) / Q2_K (軽量)
- モデルサイズ例: Llama 3 8B Q4 ≈ 4.7GB (VRAM 6GB以上推奨)

**2. チャットUI**
- ChatGPT風のチャット画面
- システムプロンプト設定
- 会話履歴管理
- 温度 / Top-P / Max Tokens などパラメータ調整

**3. ローカルサーバー (OpenAI互換API)**
- `http://localhost:1234/v1` で OpenAI API と互換
- `/v1/chat/completions` / `/v1/completions` / `/v1/embeddings`
- 既存の OpenAI SDK コードをURLとキー変更だけで動作
- 複数の外部アプリから同時接続可能

**4. GPU加速対応**
| GPU | 対応 | 備考 |
|-----|------|------|
| NVIDIA CUDA | ✅ | VRAM 6GB+ 推奨 |
| Apple Silicon (MPS) | ✅ | M1/M2/M3/M4 全対応 |
| AMD ROCm | ✅ | Linux のみ |
| CPU (AVX2) | ✅ | GPUなしでも動作 (低速) |

### 対応モデル例 (2026年時点)

| モデル | パラメータ | VRAM目安 | 特徴 |
|--------|-----------|---------|------|
| Llama 3.2 3B Q4 | 3B | 3GB | 高速・軽量・日本語OK |
| Llama 3.1 8B Q4 | 8B | 6GB | バランス最良・高品質 |
| Mistral 7B Q4 | 7B | 5GB | 英語コード生成強 |
| Phi-3 Mini Q4 | 3.8B | 4GB | Microsoft製・推論強 |
| Gemma 2 9B Q4 | 9B | 7GB | Google製・マルチリンガル |
| DeepSeek-R1 7B Q4 | 7B | 6GB | 数学・推論特化 |
| Qwen2.5 7B Q4 | 7B | 6GB | 中国語・日本語対応 |

### プライバシー・セキュリティ
```
[データフロー]
ユーザー入力 → LM Studio → llama.cpp → ローカルGPU/CPU → 応答
(インターネット通信: モデルダウンロード時のみ)
(推論時: 完全ローカル / 外部サーバー送信なし)

適用シナリオ:
  ✅ 医療記録の要約・分析
  ✅ 法律文書の秘密保持
  ✅ 社内機密データの処理
  ✅ GDPR/個人情報保護法対応
  ✅ エアギャップ環境での運用
```

### 競合との差別化
| 項目 | LM Studio | Ollama | Jan.ai | GPT4All |
|------|-----------|--------|--------|---------|
| GUI | ✅ 高品質 | △ (CLI中心) | ✅ | ✅ |
| モデル管理 | ✅ HF統合 | ✅ | ✅ | ✅ |
| OpenAI互換API | ✅ | ✅ | ✅ | △ |
| 日本語サポート | ✅ | ✅ | △ | △ |
| GPU加速 | ✅ 全GPU | ✅ | ✅ | △ |
| 使いやすさ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |

### 自分株式会社での活用可能性
- **社内データ処理**: 従業員の個人情報・業務データをクラウド送信せずAI処理
- **コスト削減**: API費用ゼロで日常的なテキスト生成・分類タスクを実行
- **AI大学コンテンツ**: 「ローカルLLMを動かしてみよう」入門コンテンツの素材
- **オフライン対応**: インターネット不要な環境でのAI機能提供$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lmstudio',
  'api',
  'LM Studio API — OpenAI互換ローカルAPI / Python/TypeScript統合 / Supabase EF連携',
  $$## LM Studio API / 統合ガイド

### 概要
LM Studio のローカルサーバーは `http://localhost:1234` で OpenAI API と完全互換の REST API を提供。既存の OpenAI SDK コードをほぼ変更なしにローカルLLMへ切り替えできる。

### セットアップ
1. LM Studio を起動
2. 左メニュー「Local Server」→ モデルを選択してロード
3. 「Start Server」をクリック → `http://localhost:1234` で起動

### Python (openai SDK 使用)
```python
from openai import OpenAI

# LM Studio のローカルエンドポイントを指定
client = OpenAI(
    base_url="http://localhost:1234/v1",
    api_key="lm-studio",  # ダミーキー (ローカルなので不要)
)

def chat_with_local_llm(prompt: str, system: str = "") -> str:
    """LM Studio のローカルLLMにチャットリクエストを送信"""
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})

    response = client.chat.completions.create(
        model="local-model",  # LM Studio では任意文字列OK
        messages=messages,
        temperature=0.7,
        max_tokens=1024,
    )
    return response.choices[0].message.content

# 使用例
answer = chat_with_local_llm(
    "Pythonでフィボナッチ数列を生成するコードを書いて",
    system="あなたは優秀なPythonエンジニアです。",
)
print(answer)
```

### TypeScript / Node.js
```typescript
import OpenAI from "openai";

const client = new OpenAI({
  baseURL: "http://localhost:1234/v1",
  apiKey: "lm-studio",
});

async function chatWithLocal(prompt: string): Promise<string> {
  const response = await client.chat.completions.create({
    model: "local-model",
    messages: [{ role: "user", content: prompt }],
    temperature: 0.7,
  });
  return response.choices[0].message.content ?? "";
}
```

### Supabase Edge Function でのプロキシパターン
```typescript
// supabase/functions/local-llm-proxy/index.ts
// 注意: Edge Function はクラウドで動くため、ローカルLM Studioには直接接続不可
// → 開発環境では環境変数でエンドポイントを切り替える

const LLM_BASE_URL = Deno.env.get("LLM_BASE_URL") ?? "https://api.openai.com/v1";
const LLM_API_KEY = Deno.env.get("LLM_API_KEY") ?? "";

Deno.serve(async (req: Request) => {
  const { prompt, model } = await req.json();

  const response = await fetch(`${LLM_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${LLM_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: model ?? "gpt-4o-mini",
      messages: [{ role: "user", content: prompt }],
    }),
  });

  const data = await response.json();
  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});

// 開発時: LLM_BASE_URL=http://host.docker.internal:1234/v1 (Docker内から)
// 本番時: LLM_BASE_URL=https://api.openai.com/v1
```

### Embeddings API
```python
# テキストのベクター埋め込み生成 (ローカル)
embedding_response = client.embeddings.create(
    model="nomic-embed-text-v1.5",  # 埋め込みモデルを別途ロード
    input="自分株式会社のライフマネジメントアプリ",
)
vector = embedding_response.data[0].embedding
print(f"次元数: {len(vector)}")  # 例: 768次元

# Supabase pgvector への保存
import supabase
sb = supabase.create_client(SUPABASE_URL, SUPABASE_KEY)
sb.table("documents").insert({
    "content": "テキスト",
    "embedding": vector,
}).execute()
```

### 量子化レベルの選択指針
```
Q2_K: VRAMが少ない / 速度優先 / 精度は低下
Q4_K_M: 最も人気 / バランス良好 / 推奨スタート地点
Q5_K_M: Q4より高精度 / VRAM+1GBが必要
Q6_K: ほぼフル精度 / VRAM余裕がある場合
Q8_0: フル精度に近い / 大容量VRAM必要 (8B→8GB)
F16: 完全精度 / VRAM×2倍必要 / 研究用途
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'lmstudio',
  'models',
  'LM Studio 技術詳細 — llama.cpp アーキテクチャ / GGUF形式 / 量子化技術 / ローカルRAG構築',
  $$## LM Studio 技術詳細

### llama.cpp バックエンド

LM Studio は **llama.cpp** (Georgi Gerganov 作の C++ LLM推論エンジン) をバックエンドに使用。

```
[llama.cpp の特徴]

1. CPU最適化 (AVX/AVX2/AVX-512)
   - NVIDIAなしでも動作 (低速だが実用的)
   - Apple Silicon: Metal API で高速化 (M1/M2/M3/M4)

2. GGUF フォーマット (2023年8月〜)
   - 旧GGML形式を置き換えた統一フォーマット
   - メタデータ (モデルアーキテクチャ・語彙・量子化情報) を内包
   - Hugging Face Hub での配布標準

3. 量子化 (Quantization)
   - FP16 (65億パラメータ = 13GB) → Q4_K_M (4.7GB) に圧縮
   - 精度損失を最小化しつつ VRAM使用量を大幅削減
   - 量子化アルゴリズム: GPTQ / AWQ / GGUF Q (独自)
```

### GGUF 量子化の仕組み

```
元のモデルウェイト (FP32 = 4バイト/パラメータ)
       ↓ 量子化
Q4_K_M (約4.5ビット/パラメータ) に圧縮

[量子化の種類]
Q_K_S: 全レイヤーを均一に量子化 (速度優先)
Q_K_M: 重要レイヤーは高精度 + 他は低精度 (バランス)
Q_K_L: より多くのレイヤーを高精度保持 (精度優先)
IQ系 (Importance Quantization): 注意機構を精度優先 (最新)
```

### ローカルRAG (Retrieval-Augmented Generation)

LM Studio + Embeddings + pgvector でプライバシー完全保護のRAGを構築:

```python
# ローカルRAGパイプライン例
import numpy as np
from openai import OpenAI

client = OpenAI(base_url="http://localhost:1234/v1", api_key="x")

# Step 1: 文書を埋め込みベクター化
def embed(text: str) -> list[float]:
    return client.embeddings.create(
        model="nomic-embed-text-v1.5",
        input=text,
    ).data[0].embedding

# Step 2: コサイン類似度で関連文書検索
def cosine_sim(a: list[float], b: list[float]) -> float:
    a_arr, b_arr = np.array(a), np.array(b)
    return float(np.dot(a_arr, b_arr) / (np.linalg.norm(a_arr) * np.linalg.norm(b_arr)))

# Step 3: 関連文書を文脈に含めて生成
def rag_answer(query: str, docs: list[str]) -> str:
    q_emb = embed(query)
    ranked = sorted(docs, key=lambda d: cosine_sim(q_emb, embed(d)), reverse=True)
    top_docs = ranked[:3]
    context = "\n\n".join(top_docs)
    prompt = f"文脈:\n{context}\n\n質問: {query}\n回答:"
    return client.chat.completions.create(
        model="local-model",
        messages=[{"role": "user", "content": prompt}],
    ).choices[0].message.content
```

### ハードウェア別推奨構成

| スペック | 推奨モデル | 速度 (tokens/sec) |
|---------|-----------|----------------|
| M2 MacBook Air (8GB) | Llama 3.2 3B Q4 | ~35 t/s |
| M3 MacBook Pro (16GB) | Llama 3.1 8B Q4 | ~40 t/s |
| M4 Pro (24GB) | Llama 3.1 70B Q4 | ~15 t/s |
| NVIDIA RTX 4070 (12GB) | Llama 3.1 8B Q8 | ~60 t/s |
| NVIDIA RTX 4090 (24GB) | Llama 3.1 70B Q4 | ~25 t/s |
| CPU only (Ryzen 9) | Phi-3 Mini Q4 | ~5 t/s |

### 自分株式会社との関連性

```
活用シナリオ:
1. 開発環境: 本番はOpenAI API → 開発/テストはLM Studioで完全ローカル
   → API費用ゼロ / レート制限なし / オフライン開発可能

2. 機密処理EF: Edge Functionの前段でローカルLLMによる前処理
   → PII (個人情報) をクラウドLLMに送信しない設計

3. AI大学コンテンツ素材:
   「ChatGPTを使わずにAIアシスタントを作る方法」
   「ローカルLLMでプライバシー保護AIアプリを構築」
   日本語技術ブログで高アクセスが見込まれるテーマ

4. ユーザー向け機能:
   将来的にPC版クライアントを提供する場合、
   LM Studio相当のローカルAI機能を組み込む選択肢
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 240→241社化: LM Studio 追加',
  'PS#3 S73。LM Studio (ローカルLLM実行GUI/llama.cppバックエンド/GGUF形式/OpenAI互換API/NVIDIA+Apple Silicon+AMD対応/完全プライバシー保護/9/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
