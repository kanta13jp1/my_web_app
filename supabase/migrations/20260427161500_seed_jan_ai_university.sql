-- PS#3 S74: AI大学 243→244社化 — Jan.ai 追加
-- Jan.ai: オープンソースローカルLLMクライアント / LM Studio対抗 / GitHub 30k+ / 拡張機能システム / OpenAI互換API

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'jan_ai',
  'overview',
  'Jan.ai — オープンソースローカルLLMクライアント (GitHub 30k+ / 拡張機能 / LM Studio対抗 / 完全プライバシー)',
  $$## Jan.ai — オープンソースローカルAIプラットフォーム

**カテゴリ**: Local LLM / On-Device AI / Open Source / Privacy-First AI
**開発元**: Jan HQ Pte. Ltd. (シンガポール)
**創業者**: Nguyen Tue Anh (元 Homebrew founder)
**設立**: 2023年
**ライセンス**: AGPLv3 (オープンソース)
**GitHub**: github.com/janhq/jan (30,000+ スター)
**対応OS**: Windows / macOS (Apple Silicon + Intel) / Linux
**価格**: 完全無料 (オープンソース)
**評価**: 8/9

### 概要
Jan.ai は **「完全オープンソースのローカルAIアシスタント」** として開発されたプラットフォーム。LM Studio と同様にローカルLLMを簡単に動かすことができるが、**完全オープンソース (AGPL)** である点と、**拡張機能システム (Extensions)** による高度なカスタマイズ性が差別化要素。ChatGPTの完全なプライベート代替として機能する。

**LM Studio との違い**:
- Jan.ai: 完全OSS (ソース公開) / AGPL / 拡張機能エコシステム
- LM Studio: プロプライエタリ (ソース非公開) / 無料だが商用ライセンス
- 両者ともローカルLLMのデファクトツールとして競合関係

**日本での普及**: GitHub日本語issueが存在し、Zenn/Qiita での解説記事も増加中。プライバシー意識の高い開発者・研究者に支持。

### 主な機能

**1. マルチエンジン対応**
| エンジン | 対応モデル形式 | 用途 |
|---------|-------------|------|
| Llama.cpp | GGUF | メインエンジン / CPU+GPU |
| TensorRT-LLM | TRT-LLM | NVIDIA GPU最適化 |
| Nitro | 独自形式 | Jan開発の高速エンジン |
| Python Extension | 任意 | カスタムモデルサーバー |

**2. リモートAPI統合**
- OpenAI / Anthropic Claude / Google Gemini / Mistral / Groq など
- ローカルとリモートを**同一インターフェース**で切り替え可能
- APIキーを設定するだけで統合 → プロバイダーに依存しない

**3. 拡張機能システム (Extensions)**
```
[主要 Extension]
- Model Management: HuggingFace直接検索・ダウンロード
- Cortex: Jan専用高性能推論エンジン
- TensorRT Extension: NVIDIA GPU最大活用
- Web Search: Brave Search API でリアルタイム検索をLLMに付加
- Function Calling: JSON Schema でツール呼び出し定義
```

**4. ローカルサーバー**
- OpenAI互換API: `http://localhost:1337/v1`
- 複数のAIアプリから同時接続可能
- CORS設定でブラウザアプリとの統合も可能

**5. ファイル・知識ベース**
- PDF / TXT / DOCX / Markdown ファイルをアップロード
- ローカルRAG: ドキュメントに基づいた質問応答
- ベクター埋め込みもローカルで完結

### サポートするモデル例
```
人気モデル (JanのModel Hub から1クリックダウンロード):
  ├── Llama 3.2 3B / 8B / 70B (Meta)
  ├── Mistral 7B / Mixtral 8x7B
  ├── Phi-3 Mini / Medium (Microsoft)
  ├── Gemma 2 2B / 9B (Google)
  ├── DeepSeek R1 / V3 (中国製・数学/推論)
  ├── Qwen 2.5 / QwQ (Alibaba・日本語対応)
  ├── CodeLlama / Codestral (コード特化)
  └── nomic-embed-text (埋め込み用)
```

### プライバシー設計
```
[完全ローカル動作の保証]

データ送信先:
  ✅ モデルダウンロード: Hugging Face / Jan Model Hub
  ✅ Web Search Extension: Brave Search API (設定した場合のみ)
  ❌ 推論時: 外部送信なし

Jan のプライバシー原則:
  1. 会話データをサーバーに送らない
  2. ユーザーデータを学習に使用しない
  3. ソースコードが公開されているため検証可能 (AGPL)
  4. テレメトリはオプトアウト可能

→ 医療・法律・財務データの処理に適合
```

### Jan vs LM Studio の選択指針
```
Jan.ai を選ぶ場合:
  ✅ 完全オープンソースにこだわる
  ✅ 拡張機能で機能を追加したい
  ✅ Web検索をLLMに付加したい
  ✅ 企業ネットワーク内でのデプロイ (ライセンス問題なし)
  ✅ 開発者・エンジニア向け

LM Studio を選ぶ場合:
  ✅ 初心者に優しいUI
  ✅ モデル探索・管理のUXが最優先
  ✅ 安定した商用サポートが欲しい
  ✅ Windows/Mac での個人利用
```

### 自分株式会社での活用可能性
- **社内AIツール**: 法的にクリーンなOSSライセンスで社内展開
- **研究・開発**: ソースコードを読んでローカルLLMの仕組みを学習
- **AI大学コンテンツ**: 「LM Studio vs Jan.ai — どちらを選ぶか」比較記事
- **プライバシー重視ユーザー向け機能**: 将来のPC版クライアントでJan.aiとの連携検討$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'jan_ai',
  'api',
  'Jan.ai API — OpenAI互換ローカルAPI / Function Calling / Supabase統合 / Web Search拡張',
  $$## Jan.ai API / 統合ガイド

### 概要
Jan.ai は `http://localhost:1337/v1` で OpenAI 互換 API を提供。LM Studio (`localhost:1234`) と同じように既存の OpenAI SDK コードをほぼ変更なしに使用できる。

### セットアップ
1. Jan.ai を起動
2. 「Settings」→「Advanced」→「Local API Server」を有効化
3. モデルをロード
4. `http://localhost:1337` でAPI利用可能

### Python (openai SDK)
```python
from openai import OpenAI

# Jan.ai のエンドポイント (LM Studioと同様のパターン)
client = OpenAI(
    base_url="http://localhost:1337/v1",
    api_key="jan",  # ローカルなのでダミーキー
)

def chat(prompt: str, model: str = "llama3.2-3b-instruct") -> str:
    """Jan.ai でテキスト生成"""
    response = client.chat.completions.create(
        model=model,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.7,
        max_tokens=1024,
        stream=False,
    )
    return response.choices[0].message.content

# 使用例
result = chat("Pythonで非同期HTTPリクエストを実装する最良の方法は？")
print(result)
```

### Function Calling (ツール呼び出し)
```python
import json

tools = [
    {
        "type": "function",
        "function": {
            "name": "get_weather",
            "description": "指定した都市の現在の天気を取得",
            "parameters": {
                "type": "object",
                "properties": {
                    "city": {
                        "type": "string",
                        "description": "都市名 (例: Tokyo, Osaka)",
                    }
                },
                "required": ["city"],
            },
        },
    }
]

response = client.chat.completions.create(
    model="llama3.2-3b-instruct",
    messages=[{"role": "user", "content": "東京の天気は？"}],
    tools=tools,
    tool_choice="auto",
)

# ツール呼び出しが発生した場合
if response.choices[0].message.tool_calls:
    tool_call = response.choices[0].message.tool_calls[0]
    function_name = tool_call.function.name
    args = json.loads(tool_call.function.arguments)
    print(f"呼び出し: {function_name}({args})")
    # → "呼び出し: get_weather({'city': 'Tokyo'})"
```

### ストリーミング
```python
def stream_chat(prompt: str) -> None:
    """ストリーミングでリアルタイム出力"""
    stream = client.chat.completions.create(
        model="llama3.2-3b-instruct",
        messages=[{"role": "user", "content": prompt}],
        stream=True,
    )
    for chunk in stream:
        delta = chunk.choices[0].delta.content
        if delta:
            print(delta, end="", flush=True)
    print()

stream_chat("量子コンピュータを小学生に説明して")
```

### Supabase Edge Function との組み合わせ
```typescript
// Jan.ai をローカル開発サーバーとして活用
// 本番: OPENAI_BASE_URL=https://api.openai.com/v1
// 開発: OPENAI_BASE_URL=http://host.docker.internal:1337/v1

const BASE_URL = Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1";
const API_KEY = Deno.env.get("OPENAI_API_KEY") ?? "jan";

Deno.serve(async (req: Request) => {
  const { message } = await req.json();

  const response = await fetch(`${BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",  // 本番 / ローカルでは "llama3.2-3b-instruct"
      messages: [{ role: "user", content: message }],
    }),
  });

  const data = await response.json();
  return new Response(JSON.stringify({
    reply: data.choices[0].message.content,
  }), { headers: { "Content-Type": "application/json" } });
});
```

### Web Search 拡張 (Brave Search API 統合)
```
[設定手順]
1. Brave Search API キーを取得 (無料枠あり)
2. Jan.ai: Settings → Extensions → Web Search
3. API キーを入力 → 有効化

[動作]
ユーザー: 「2026年のAI最新ニュースを教えて」
Jan.ai: 1. Brave Search で検索実行
        2. 検索結果をコンテキストに追加
        3. LLM が最新情報に基づいて回答
→ ローカルLLMでもリアルタイム情報を扱える
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'jan_ai',
  'models',
  'Jan.ai 技術詳細 — Cortex推論エンジン / AGPLライセンス / ローカルRAG設計 / LM Studio対比技術比較',
  $$## Jan.ai 技術詳細

### Cortex: Jan独自の推論エンジン

Jan.ai は内部的に **Cortex** (github.com/janhq/cortex.cpp) という独自の推論エンジンを開発:

```
[Cortex の設計]

アーキテクチャ:
  C++ コア (llama.cpp をベース + 独自最適化)
  ├── CPU 推論: AVX2 / AVX-512 最適化
  ├── GPU 推論: CUDA / Metal / Vulkan
  └── モデルレイヤーキャッシュ: 連続会話の高速化

Jan UI との関係:
  Jan App (Electron/React)
    ↓ HTTP
  Cortex Server (localhost)
    ↓
  llama.cpp / TensorRT / etc.

特徴:
  - OpenAI 互換 REST API をネイティブ提供
  - モデルのホットスワップ (起動中にモデル切り替え)
  - マルチモデル並列ロード (メモリ許す限り)
```

### AGPLライセンスの意味

```
[AGPL vs MIT vs Apache の違い]

MIT / Apache:
  → 改変してプロプライエタリソフトに組み込み可能
  → SaaS として提供しても公開義務なし

AGPL (GNU Affero GPL):
  → 改変してSaaSとして提供する場合もソースを公開義務
  → サーバーサイドで使う場合もコピーレフト発動

Jan.ai (AGPL) の意味:
  ✅ 個人利用: 完全無料・制限なし
  ✅ 社内利用: ソースを公開しなくて良い (外部提供しないため)
  ⚠️ SaaS組み込み: Janのコードを使ってサービス提供 → ソース公開義務
  → 自分株式会社がJanを使ってサービスを作る場合は注意が必要
```

### ローカルRAG (Retrieval-Augmented Generation) 設計

```
[Jan.ai の組み込みRAGパイプライン]

1. ドキュメント取り込み
   PDF/TXT/MD → テキスト抽出 → チャンク分割 (500〜1000トークン)

2. 埋め込み生成 (ローカル)
   nomic-embed-text or all-MiniLM-L6-v2
   → 768次元ベクター → ローカルベクターDB (FAISS/Chroma)

3. クエリ処理
   ユーザー質問 → 埋め込み → コサイン類似度検索 → TOP-K 文書取得

4. LLMへのプロンプト構築
   [system]: あなたは以下の文書に基づいて回答します
   [context]: {TOP-K 文書の内容}
   [user]: {ユーザーの質問}

5. ローカルLLMで回答生成 → 外部送信なし

→ 社内文書 / 医療記録 / 法律文書 のプライバシー保護RAGに最適
```

### パフォーマンス比較 (Llama 3.1 8B Q4_K_M)

| 環境 | Jan.ai | LM Studio | Ollama |
|------|--------|-----------|--------|
| M3 Pro 16GB | ~38 t/s | ~40 t/s | ~35 t/s |
| RTX 4070 12GB | ~58 t/s | ~62 t/s | ~55 t/s |
| CPU (Ryzen 9) | ~6 t/s | ~6 t/s | ~5 t/s |
| 初回起動時間 | ~3秒 | ~2秒 | ~1秒 |
| メモリオーバーヘッド | 中 | 低 | 最低 |

*数値は近似値。バージョン・設定により変動

### ロードマップ (2025〜2026)

```
Jan.ai 開発方針 (公式ロードマップより):

短期:
  ✅ Cortex エンジン安定化
  ✅ マルチモーダル (画像理解) 対応
  🔄 モバイル版 (iOS/Android) 開発中

中期:
  📋 MCP (Model Context Protocol) 対応
  📋 Agentic モード (自律タスク実行)
  📋 ファインチューニング UI

長期:
  📋 分散推論 (複数デバイスでモデルを分割)
  📋 プライベートクラウド版 (チーム共有)
```

### 自分株式会社との関連性

```
活用シナリオ:

1. AGPLライセンスの確認が必要なため「組み込み」には注意
   → 自分株式会社が Jan.ai のコードを使ったサービスを提供する場合
     Jan.ai コードの変更部分を公開する義務が発生

2. 開発ツールとして: ローカルRAGの設計参考・テスト環境
   → ソースコードが完全公開なので「どう実装するか」の学習に最適

3. AI大学コンテンツ:
   「Jan.ai でプライベートChatGPTを作る方法」
   「LM Studio vs Jan.ai: エンジニアが選ぶべきはどちら？」
   技術系ブログで高い検索需要が見込まれるテーマ

4. オープンソース活用の事例研究:
   AGPL と MIT の違い / OSSライセンスがビジネスに与える影響
   → 自分株式会社の技術選択時のライセンス判断基準として
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 243→244社化: Jan.ai 追加',
  'PS#3 S74。Jan.ai (オープンソースローカルLLMクライアント/AGPL/GitHub 30k+/Cortex推論エンジン/LM Studio対抗/拡張機能システム/Web Search統合/ローカルRAG/シンガポール発/8/9) を ai_university_content に追加。',
  '2026-04-27'
)
ON CONFLICT DO NOTHING;
