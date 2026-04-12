-- Ollama コンテンツシード
-- AI大学: Ollama プロバイダーの初期コンテンツ (overview / models / api)
-- 追加理由: ローカルLLM最大手 / プライバシー完全保護 / API不要・オフライン動作 / 無料無制限利用

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('ollama', 'overview', 'Ollama 概要',
$$Ollama は**ローカルLLM実行ツール**。LLaMA・Gemma・Mistral・DeepSeek などのオープンソースモデルを、クラウドAPIを使わず**自分のPC/サーバー上で実行**できます。データが外部に出ないためプライバシーが完全に保護され、使い放題・無料で利用できます。

## 特徴

- **完全ローカル実行**: 全データがPC内に留まる。API通信なし・インターネット不要
- **OpenAI互換API**: `http://localhost:11434/v1` でOpenAI SDKがそのまま使える
- **ワンコマンド起動**: `ollama run llama3.3` だけでモデルをダウンロード・実行
- **多様なモデル**: LLaMA 3・Gemma 2・Mistral・DeepSeek・Qwen・CodeLlama など
- **無料無制限**: クラウドAPIの料金・レート制限・利用規約の制約なし
- **カスタマイズ**: Modelfile でシステムプロンプト・温度・パラメータを固定化

## 用途別選択

```text
汎用会話      → llama3.3 (70B) / gemma2 (27B)
コード生成    → codellama / deepseek-coder-v2
日本語        → llama3.3 / qwen2.5 (中国製・日本語強)
高速・軽量    → llama3.2 (3B) / gemma2 (2B) / phi4-mini
プライバシー  → 全モデル (デフォルトでローカル実行)
エンタープライズ → llama3.1 (405B) ※高性能GPU必要
```

## 必要スペック

| モデルサイズ | VRAM目安 | 対応GPU例 |
| :--- | :--- | :--- |
| 3B | 4GB | RTX 3060, M1 Mac |
| 7B | 8GB | RTX 3070, M2 Mac |
| 13B | 16GB | RTX 3090, M3 Pro |
| 70B | 48GB (量子化で24GB〜) | RTX 4090×2, M3 Ultra |
| CPU実行 | RAM 16GB〜 | GPUなし・低速 |

## プライバシーが重要な場面

- 医療・法務・金融など機密データのAI処理
- 社内文書の要約・検索
- 個人情報を含む顧客データ分析
- 社内コードのコードレビュー (外部送信不可な場合)$$,
'https://ollama.com/', '2026-04-12', 1),

('ollama', 'models', 'Ollama — 利用可能モデル (2026)',
$$Ollama では `ollama pull <model>` でモデルをダウンロードして即実行できます。

## 汎用チャットモデル

| モデル | パラメータ | VRAM | 特徴 |
| :--- | :--- | :--- | :--- |
| `llama3.3` | 70B | 48GB | Meta最高性能・多言語対応 |
| `llama3.2` | 3B / 1B | 2GB〜 | 軽量・高速 |
| `gemma2` | 27B / 9B / 2B | 16GB〜 | Google製・効率的 |
| `mistral` | 7B | 8GB | 欧州製・バランス型 |
| `qwen2.5` | 72B / 32B / 7B | 48GB〜 | Alibaba・日本語強 |
| `phi4` | 14B | 10GB | Microsoft・コンパクト高性能 |

## コード特化モデル

| モデル | パラメータ | 特徴 |
| :--- | :--- | :--- |
| `codellama` | 34B / 13B / 7B | Meta製コード生成 |
| `deepseek-coder-v2` | 16B | DeepSeek製・コード最強クラス |
| `codegemma` | 7B | Google製コードモデル |
| `starcoder2` | 15B / 7B / 3B | BigCode製・コードの多言語対応 |

## 日本語対応モデル

| モデル | 特徴 |
| :--- | :--- |
| `llama3.3` (70B) | 日本語含む多言語。大きいが高品質 |
| `qwen2.5` (7B〜) | 中国・アリババ製。日本語非常に強い |
| `gemma2` (9B) | 日本語品質良好。軽量 |

## カスタムモデル (Modelfile)

```dockerfile
# 日本語カスタマーサポートBot の例
FROM llama3.3

SYSTEM """
あなたは自分株式会社のカスタマーサポートAIです。
ユーザーの質問に日本語で丁寧に回答してください。
個人情報に関する質問には回答しないでください。
"""

PARAMETER temperature 0.3
PARAMETER top_p 0.9
```

```bash
# カスタムモデルをビルド・実行
ollama create cs-bot -f Modelfile
ollama run cs-bot
```$$,
'https://ollama.com/library', '2026-04-12', 2),

('ollama', 'api', 'Ollama API 入門',
$$## インストール

```bash
# macOS / Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows: https://ollama.com/download から installer をダウンロード

# モデルのダウンロードと実行 (初回のみダウンロード)
ollama run llama3.2           # 軽量モデル (3B, ~2GB)
ollama run qwen2.5:7b         # 日本語強モデル (7B, ~4GB)
```

## Python SDK (OpenAI互換)

```python
from openai import OpenAI

# base_url をローカルに向けるだけ — あとはOpenAI SDKと同じ
client = OpenAI(
    base_url="http://localhost:11434/v1",
    api_key="ollama",  # ダミーでOK (認証なし)
)

# チャット補完
response = client.chat.completions.create(
    model="llama3.2",  # ollama pull 済みのモデル名
    messages=[
        {"role": "system", "content": "あなたは親切なAIアシスタントです。"},
        {"role": "user", "content": "Flutterの状態管理で人気のパッケージを3つ教えて"},
    ],
)
print(response.choices[0].message.content)
```

## Ollama ネイティブPython SDK

```python
import ollama

# シンプルなチャット
response = ollama.chat(
    model="llama3.2",
    messages=[{"role": "user", "content": "Supabaseとは何ですか？"}],
)
print(response["message"]["content"])

# ストリーミング
for chunk in ollama.chat(
    model="qwen2.5:7b",
    messages=[{"role": "user", "content": "日本語でハイクを一句詠んでください"}],
    stream=True,
):
    print(chunk["message"]["content"], end="", flush=True)
```

## ローカルRAG: Ollama + LangChain + Supabase pgvector

```python
from langchain_ollama import OllamaEmbeddings, ChatOllama
from langchain_community.vectorstores import SupabaseVectorStore
from langchain.chains import RetrievalQA
from supabase import create_client

supabase = create_client("<SUPABASE_URL>", "<SUPABASE_KEY>")

# ローカルEmbeddingモデル (nomic-embed-text)
embeddings = OllamaEmbeddings(model="nomic-embed-text")  # ollama pull nomic-embed-text

# Supabase pgvector に接続
vectorstore = SupabaseVectorStore(
    client=supabase,
    embedding=embeddings,
    table_name="documents",
    query_name="match_documents",
)

# ローカルLLMでRAG
llm = ChatOllama(model="llama3.2", temperature=0)
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=vectorstore.as_retriever(search_kwargs={"k": 3}),
)

# 全てローカル実行 — データ外部送信ゼロ
result = qa_chain.invoke({"query": "プライベートドキュメントの内容を教えて"})
print(result["result"])
```

## Supabase Edge Function で Ollama サーバーを呼び出す

```typescript
// 自社サーバー上のOllamaをEdge Functionから呼び出す例
const OLLAMA_URL = Deno.env.get("OLLAMA_SERVER_URL")!; // 例: http://192.168.1.100:11434

export async function callLocalLLM(prompt: string): Promise<string> {
  const res = await fetch(`${OLLAMA_URL}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "llama3.2",
      messages: [{ role: "user", content: prompt }],
      stream: false,
    }),
  });

  const data = await res.json();
  return data.message.content;
}
```

## コスト比較

| 項目 | Ollama (ローカル) | クラウドAPI |
| :--- | :--- | :--- |
| API料金 | **$0 (無料)** | $0.15〜$75/1M tokens |
| レート制限 | **なし** | あり |
| プライバシー | **完全保護** | プロバイダーに送信 |
| モデル選択 | OSSのみ | 最新商用モデルも可 |
| セットアップ | GPU/RAM必要 | 即時利用可 |$$,
'https://ollama.com/docs', '2026-04-12', 3)

ON CONFLICT DO NOTHING;

-- 開発実績
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 Ollama 追加 (30社目)',
  'OllamaをAI大学プロバイダーとして追加。ローカルLLM実行ツール・完全プライバシー保護・OpenAI互換API・LLaMA/Gemma/Mistral/Qwen対応・ローカルRAG(pgvector+LangChain)構築例を収録。AI大学プロバイダー数 29社→30社。',
  '2026-04-12'
)
ON CONFLICT DO NOTHING;
