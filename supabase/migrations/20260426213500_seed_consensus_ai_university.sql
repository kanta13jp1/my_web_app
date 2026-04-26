-- PS#3 S66: AI大学 227→228社化 — Consensus 追加
-- Consensus: AI学術論文検索エンジン / 科学的根拠のある回答 / 200M+論文 / GPT-4統合

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'consensus',
  'overview',
  'Consensus — AI学術論文検索エンジン (200M+論文/科学的根拠回答/Consensus Meter/GPT-4統合)',
  $$## Consensus — AI学術論文検索エンジン

**カテゴリ**: AI Research Tool / Academic Search / Scientific Evidence Platform
**設立**: 2022年 / 本社: San Francisco, CA / 資金調達: ~$10M (FirstMark / Slow Ventures)
**特徴**: 200M+件の学術論文をAIで検索し、科学的根拠に基づいた回答を提供。ChatGPTのハルシネーションとは異なり、全回答に論文ソースを明示
**ユーザー**: 研究者 / 医療専門家 / MBA学生 / エビデンスベース意思決定者 / コンサルタント
**評価**: 8/9

### 概要
Consensus は **「ChatGPTのような質問応答 + Google Scholarのような論文網羅性」** を実現するAI学術検索エンジン。「コーヒーは健康に良いか?」「リモートワークは生産性を上げるか?」「睡眠6時間vs8時間の認知影響は?」など、科学的根拠が求められる質問に対して、関連する査読済み論文を自動収集・要約し、**Consensus Meter** (研究の賛否割合) を可視化する。

ChatGPT が「それっぽい回答」を生成するのに対し、Consensus は必ず **実在する論文** を根拠とする点が核心的差別化。

### 主な機能

**AI検索 + 論文サマリー**
- 自然言語質問 → 関連論文TOP10を瞬時に抽出
- GPT-4が各論文の主要知見を1〜2文で要約
- 論文ごとに: タイトル / ジャーナル / 引用数 / 年 / 著者 / Abstract を表示
- 200M+件の論文カバレッジ (PubMed / Semantic Scholar / arXiv 等)

**Consensus Meter**
- 質問に対して研究界全体の「賛成 / 反対 / 不明」割合を可視化
- 例: 「間欠的断食は体重減少に効果的か?」
  → 賛成 68% / 反対 11% / 不明 21% (◉ 強いコンセンサスあり)
- 例: 「コーヒーは心臓病リスクを下げるか?」
  → 賛成 52% / 反対 29% / 不明 19% (○ 弱いコンセンサス)

**Copilot (GPT-4統合)**
- 複数論文を横断して総合的な回答を生成
- 「研究では〜と示されている (Smith et al., 2023)」形式でソース付き回答
- 関連する後続質問を自動提案
- 論文の引用形式 (APA/MLA/BibTeX) を自動生成

**Study Snapshots**
- 個別論文のAIサマリー: Sample size / Methods / Results / Limitations
- 「この研究の限界は?」「実験デザインは?」をワンクリックで把握

### 対応研究分野
医学・健康 / 心理学 / 経営・マーケティング / コンピュータサイエンス / 経済学 / 環境科学 / 教育学 / 栄養学 / 神経科学 / 物理学 / etc.

### ユースケース例
```
ビジネス意思決定:
  Q: 「4日間労働週は生産性に影響するか?」
  → Consensus: 20件の論文 / 85%が生産性維持または向上を報告
  → 根拠付き社内提案資料が5分で完成

医療・健康:
  Q: 「メラトニンは睡眠の質を改善するか?」
  → 査読済み臨床試験15件 / 標準用量0.5mgで入眠時間平均7分短縮

マーケティング戦略:
  Q: 「ソーシャルプルーフは購買意欲に影響するか?」
  → 43件の消費者行動研究 / 平均コンバージョン向上率12-18%
```

### 競合との差別化
| 項目 | Consensus | Google Scholar | ChatGPT | Perplexity |
|------|----------|---------------|---------|-----------|
| 論文専門 | ✅ 学術特化 | ✅ | ❌ | △ |
| AI要約 | ✅ 高精度 | ❌ | ✅ (ハルシネーション有) | ✅ |
| ソース明示 | ✅ 必須 | ✅ | △ | ✅ |
| 賛否可視化 | ✅ Meter | ❌ | ❌ | ❌ |
| 論文数 | 200M+ | 200M+ | 学習データのみ | Web |
| 査読フィルター | ✅ | △ | ❌ | ❌ |

### 導入コスト
- **Free**: 月20検索 / 基本機能 / Consensus Meter
- **Premium**: 月$8.99 / 無制限検索 / Copilot / Study Snapshots / 引用エクスポート
- **Teams**: 月$9.99/ユーザー / チーム管理 / API (10シートから)
- **Enterprise**: カスタム / SSO / 高度な分析 / 専任サポート$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'consensus',
  'api',
  'Consensus API — 論文検索・要約取得・引用エクスポート (Python/TypeScript)',
  $$## Consensus API

### 概要
Consensus は Teams / Enterprise プランで REST API を提供。論文検索・要約取得を自動化できる。

### セットアップ
```bash
# Consensus → Settings → API でキー取得 (Teams/Enterprise)
export CONSENSUS_API_KEY="your_api_key_here"
export CONSENSUS_BASE="https://consensus.app/api/v1"
```

### 論文検索 (Python)
```python
import requests
import os

CONSENSUS_API_KEY = os.environ["CONSENSUS_API_KEY"]
CONSENSUS_BASE = os.environ["CONSENSUS_BASE"]

HEADERS = {
    "Authorization": f"Bearer {CONSENSUS_API_KEY}",
    "Content-Type": "application/json",
}

def search_papers(query: str, limit: int = 10, year_from: int = 2020) -> dict:
    """学術論文検索 + AI要約取得"""
    payload = {
        "query": query,
        "filters": {
            "year_from": year_from,
            "peer_reviewed": True,      # 査読済み論文のみ
            "sample_size_min": 50,      # サンプルサイズ50以上
        },
        "limit": limit,
        "include_summary": True,        # AI要約を含める
        "include_consensus_meter": True, # 賛否スコアを含める
    }
    resp = requests.post(
        f"{CONSENSUS_BASE}/search",
        json=payload,
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

# AI × 生産性の研究を検索
results = search_papers(
    query="AI tools impact on knowledge worker productivity",
    limit=10,
    year_from=2022,
)

print(f"Consensus Meter: {results['consensus_meter']}")
print(f"  賛成: {results['consensus_meter']['yes_pct']}%")
print(f"  反対: {results['consensus_meter']['no_pct']}%")
print()

for paper in results["papers"]:
    print(f"📄 {paper['title']}")
    print(f"   著者: {paper['authors'][0]} et al. ({paper['year']})")
    print(f"   ジャーナル: {paper['journal']}")
    print(f"   要約: {paper['ai_summary']}")
    print(f"   引用数: {paper['citation_count']}")
    print()
```

### Copilot API (複数論文横断回答)
```python
def ask_copilot(question: str, max_papers: int = 20) -> dict:
    """GPT-4 Copilotで複数論文を横断した総合回答を取得"""
    payload = {
        "question": question,
        "max_papers": max_papers,
        "response_language": "ja",  # 日本語回答
        "include_citations": True,
    }
    resp = requests.post(
        f"{CONSENSUS_BASE}/copilot",
        json=payload,
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()

# 自分株式会社の戦略意思決定に活用
answer = ask_copilot(
    question="What does research say about effectiveness of AI-powered personal productivity apps?",
)
print("回答:")
print(answer["response"])
print()
print("引用論文:")
for citation in answer["citations"]:
    print(f"  [{citation['number']}] {citation['title']} ({citation['year']})")
```

### 引用エクスポート + BibTeX生成
```python
def export_citations(paper_ids: list, format: str = "bibtex") -> str:
    """論文の引用情報をBibTeX/APA/MLAでエクスポート"""
    resp = requests.post(
        f"{CONSENSUS_BASE}/export/citations",
        json={"paper_ids": paper_ids, "format": format},
        headers=HEADERS,
    )
    resp.raise_for_status()
    return resp.json()["content"]

# 論文引用をBibTeXで取得
bibtex = export_citations(
    paper_ids=["paper_id_1", "paper_id_2"],
    format="bibtex",
)
with open("references.bib", "w") as f:
    f.write(bibtex)
```

### GHA × Consensus AI大学コンテンツ自動強化
```yaml
# .github/workflows/ai-university-research-update.yml
# 毎週日曜 20:00 JST → Consensus API → AI大学コンテンツに最新論文エビデンスを追加
steps:
  - name: Fetch latest AI research evidence
    env:
      CONSENSUS_API_KEY: ${{ secrets.CONSENSUS_API_KEY }}
      SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
    run: |
      python scripts/update_ai_university_with_research.py \
        --topics "large language models,AI agents,RAG,multimodal AI" \
        --year-from 2024 \
        --table ai_university_content
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'consensus',
  'models',
  'Consensus AI技術詳細 — Semantic Search + Consensus Meter計算 + ハルシネーション対策アーキテクチャ',
  $$## Consensus AI 技術詳細

### 検索アーキテクチャ
```
[Consensus の検索パイプライン]

ユーザークエリ (自然言語)
       ↓
Query Understanding (GPT-4):
  - クエリを学術的な概念に変換
  - 関連する研究用語・同義語を展開
  - 研究分野を特定 (医学/心理/経営等)
       ↓
Semantic Search (Vector DB):
  - 200M+論文のembeddingと比較
  - コサイン類似度でTop-1000件取得
  - Semantic Scholar / PubMed / arXiv から取得
       ↓
Relevance Reranking:
  - 論文の査読ステータス / 引用数 / 年 / ジャーナルインパクトファクター でスコアリング
  - クエリとAbstractの意味的類似度で再ランク
  - 最終Top-10〜50件を選定
       ↓
AI Summarization (GPT-4):
  - 各論文のAbstract + Methodsを読んで1〜2文の要約生成
  - 「賛成/反対/不明」の立場を判定
       ↓
Consensus Meter計算:
  - Top-50論文の立場を集計してパーセンテージ化
  - 信頼区間計算 (論文数が少ない場合は「不十分なエビデンス」表示)
       ↓
出力: 論文リスト + 要約 + Consensus Meter + Copilot回答
```

### ハルシネーション対策の設計
```
[ChatGPT との根本的違い]

ChatGPT / 一般的LLM:
  → 学習データから「それらしい回答」を生成
  → 実在しない論文・著者・統計を作り出す可能性 (ハルシネーション)
  → ソース確認が困難

Consensus:
  → 回答の根拠は必ず実在する論文
  → DOI / PubMed ID / Semantic Scholar ID を常に明示
  → GPT-4はあくまで「要約と統合」のみ (新情報を生成しない)
  → 論文が見つからない場合は「エビデンス不十分」と正直に表示

→ これにより「科学的根拠のある意思決定」が可能になる
→ 医療 / 法律 / 政策 など、根拠が求められる分野で特に価値高い
```

### Consensus Meter の信頼性モデル
```
Consensus Meter の評価基準:

🟢 Strong Consensus (強いコンセンサス):
  - 賛成 >70% かつ 論文数 >15件
  - 例: "Exercise improves mental health" → 82%, 47件

🟡 Moderate Consensus (弱いコンセンサス):
  - 賛成 50-70% かつ 論文数 8-15件
  - 例: "Coffee reduces Alzheimer's risk" → 61%, 12件

🔴 Disputed (議論中):
  - 賛成 30-50% または 反対が多い
  - 例: "Social media causes depression" → 48%, 21件

⚪ Insufficient Evidence (根拠不足):
  - 論文数 <5件 または 質の低い研究が多い
  - 例: 非常に新しいトピック

→ エビデンスの質と量を透明に開示
```

### 自分株式会社での活用可能性
- **AI大学コンテンツ強化**: 各AIプロバイダーの「効果」「ROI」「導入事例」に関する学術的エビデンスをConsensus APIで自動収集 → コンテンツの信頼性を学術根拠で担保
- **プロダクト意思決定**: 新機能開発前にConsensusで「その機能がユーザー価値向上につながるか」の根拠を収集
- **投資家向け資料**: 市場サイズ・AI普及率・生産性向上効果の学術根拠を自動収集してピッチデッキに組み込む
- **ウェルビーイング機能**: 自分株式会社の「健康管理」機能の推奨事項に学術エビデンスを付与 (信頼性向上)
- **SEOコンテンツ**: AI大学の記事に「研究によると〜 (N件の論文で支持)」という表現をConsensus APIで自動生成$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 227→228社化: Consensus 追加',
  'PS#3 S66。Consensus (AI学術論文検索エンジン/200M+論文/Consensus Meter賛否可視化/GPT-4 Copilot/ハルシネーション対策設計/査読済み論文特化/FirstMark/~$10M/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
