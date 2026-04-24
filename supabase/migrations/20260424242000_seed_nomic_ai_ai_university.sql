-- Session PS#3-S33: AI大学 161社化 — Nomic AI 追加
-- Brandon Duderstadt + Andriy Mulyar が 2021 年に NYC で創業した OSS 特化 AI インフラ企業。
-- $17M Series A (2023-07 / Coatue 主導 / Contrary・Betaworks・SV Angel 参加)。
-- nomic-embed-text: 8192 トークン長コンテキスト・Apache 2.0 open weights・OpenAI ada-002 超え。
-- Nomic Embed v2: 137M params・CPU 推論可・マルチモーダル (text + vision)。
-- Atlas: 高次元データ可視化・探索プラットフォーム (数百万ドキュメントをブラウザで可視化)。
-- 既存 160 社の「embeddings 軸」空白を埋める — Weaviate(vector DB) と補完関係。
-- Step 0: 8/9 (Apache 2.0 OSS / Ollama 対応 / MTEB SOTA / Coatue 調達 / Atlas UI 独自価値)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES

(
  'nomic_ai',
  'overview',
  'Nomic AI — オープンソース特化 Embedding & データ可視化 AI インフラ',
  $md$
# Nomic AI — Open Source AI for Everyone

2021 年創業。**Brandon Duderstadt + Andriy Mulyar** が「AI モデルの透明性と再現性」を
ミッションに NYC で設立。

**nomic-embed-text** は 8,192 トークンの長コンテキストに対応した
テキスト埋め込みモデルで、OpenAI の `text-embedding-ada-002` と
`text-embedding-3-small` を上回るパフォーマンスを MTEB ベンチマークで達成。
**Apache 2.0 ライセンス**で weights・学習コード・データセットをすべて公開した
初の「完全再現可能な」embedding モデルとして知名度を獲得。

2023 年 7 月に **Coatue** 主導で **$17M Series A** を調達
(Contrary Capital・Betaworks Ventures・SV Angel 参加)。

## 主要プロダクト

- **nomic-embed-text** — 長コンテキスト (8,192 トークン) テキスト embedding
- **nomic-embed-vision** — テキスト・画像を同一ベクター空間にマッピングするマルチモーダル embedding
- **nomic-embed-code** — コード向け embedding モデル
- **Nomic Atlas** — 数百万件のドキュメントをブラウザ上でインタラクティブに可視化・探索するプラットフォーム

## 強み

- **完全 OSS** — Apache 2.0 / weights・コード・データすべて公開 (Hugging Face)
- **エッジ推論対応** — Nomic Embed v2 (137M params) は CPU で本番推論可能
- **Ollama 対応** — `ollama pull nomic-embed-text` でローカル実行
- **Matryoshka Embeddings** — 次元を削減しながら性能を維持可能 (コスト最適化)
- **LangChain / LlamaIndex 公式統合** でゼロコスト embedding パイプライン構築
$md$,
  'https://www.nomic.ai/',
  '2026-04-24',
  1
),

(
  'nomic_ai',
  'models',
  'Nomic Embed モデル一覧 (2026)',
  $md$
## Nomic Embed モデル比較

| モデル | パラメータ | コンテキスト長 | 次元数 | 特徴 |
| :--- | :--- | :--- | :--- | :--- |
| **nomic-embed-text-v1.5** | 137M | 8,192 tokens | 768 (可変) | Matryoshka / MTEB SOTA |
| **nomic-embed-vision-v1.5** | 223M | — | 768 | テキスト・画像共通空間 |
| **nomic-embed-code** | 137M | 2,048 tokens | 768 | コード検索特化 |

## MTEB ベンチマーク (2024 / nomic-embed-text-v1.5)

| 比較対象 | スコア差 |
| :--- | :--- |
| vs OpenAI text-embedding-ada-002 | +2.1pt 上回る |
| vs OpenAI text-embedding-3-small | +0.7pt 上回る |
| 長コンテキスト (>2K tokens) | 特に優位 |

## Nomic Atlas — データ可視化

| 機能 | 説明 |
| :--- | :--- |
| **インタラクティブマップ** | 数百万件の文書をブラウザで 2D/3D 可視化 |
| **クラスタリング** | 自動トピック抽出・ラベリング |
| **重複検出** | 類似文書のグルーピング |
| **データ品質分析** | 外れ値・偏り検出 |

## 料金

| プラン | 月額 | 用途 |
| :--- | :--- | :--- |
| **Free** | $0 | 個人・OSS (Ollama / HuggingFace) |
| **API (Nomic Atlas)** | 従量課金 | クラウド inference |
| **Enterprise** | 要相談 | オンプレ / カスタム |
$md$,
  'https://docs.nomic.ai/',
  '2026-04-24',
  2
),

(
  'nomic_ai',
  'api',
  'Nomic Embed API 入門',
  $md$
## Nomic Embed の始め方

### Python SDK (公式)

```python
# pip install nomic

from nomic import embed

# テキスト embedding (無料・ローカル or API)
output = embed.text(
    texts=["AI大学で最新の AI 企業を学ぶ", "nomic-embed は長コンテキストに強い"],
    model="nomic-embed-text-v1.5",
    task_type="search_document",  # search_query / clustering / classification
)

embeddings = output["embeddings"]
print(f"次元数: {len(embeddings[0])}")   # 768
print(f"件数: {len(embeddings)}")
```

### Ollama でローカル実行 (完全無料)

```bash
# モデルをローカルに取得
ollama pull nomic-embed-text

# Python から Ollama 経由で呼び出し
import ollama

response = ollama.embed(
    model="nomic-embed-text",
    input="検索対象テキスト"
)
embedding = response["embeddings"][0]
```

### LangChain 統合

```python
from langchain_nomic.embeddings import NomicEmbeddings
from langchain_community.vectorstores import Chroma

# Nomic embedding + Chroma vector store の組み合わせ
embedding_function = NomicEmbeddings(model="nomic-embed-text-v1.5")

vectorstore = Chroma.from_texts(
    texts=["ドキュメント1", "ドキュメント2"],
    embedding=embedding_function,
)

results = vectorstore.similarity_search("検索クエリ", k=3)
```

### クイックスタート

1. `pip install nomic` でインストール
2. `nomic login` で API キー取得 (nomic.ai でアカウント作成)
3. または `ollama pull nomic-embed-text` でローカル実行 (キー不要)
4. `embed.text(texts=[...], model="nomic-embed-text-v1.5")` で embedding 生成
$md$,
  'https://docs.nomic.ai/',
  '2026-04-24',
  3
)

ON CONFLICT DO NOTHING;
