---
title: "AI大学280社データベースの設計思想 — 競合をコンテンツに変える戦略"
tags: AI,個人開発,buildinpublic,postgresql
published: true
---

# AI大学280社データベースの設計思想 — 競合をコンテンツに変える戦略

自分のアプリに「競合 280 社」のデータベースを作った。一見奇妙に見えるが、これがコンテンツ戦略として機能している。設計思想を公開する。

## 競合をコンテンツにするという発想

```
一般的な考え方: 競合は無視する / 言及しない
うちの考え方:  競合を学習リソースにする → SEO × 教育 × 差別化
```

280社の AI ツールを「学べる場所」として位置づけることで:
- 競合名で検索したユーザーが来る (SEO)
- 競合を知ることで自分のプロダクトの価値を理解できる (教育)
- 「競合さえも取り込む」という余裕が信頼につながる (差別化)

## データベーススキーマ設計

```sql
-- ai_university_content テーブル (実際の構造)
CREATE TABLE ai_university_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider_name TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,        -- 'llm', 'mlops', 'vector_db', etc
  description TEXT NOT NULL,
  key_features TEXT[] NOT NULL,  -- 主要機能リスト
  use_cases TEXT[] NOT NULL,     -- ユースケース
  pricing_model TEXT,            -- 'freemium', 'usage', 'subscription'
  github_stars INT,
  popularity_score INT,          -- 1-10
  maturity_score INT,            -- 1-10
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

280社分のデータが Supabase に入っている。Edge Function で取得して Flutter に表示。

## カテゴリ設計

```
AI大学のカテゴリ体系:
  LLM providers:    OpenAI / Anthropic / Google / Meta
  MLOps:           MLflow / Weights&Biases / Kubeflow / SageMaker
  Vector DB:       Pinecone / Weaviate / Qdrant / pgvector
  LLM Frameworks:  LangChain / LlamaIndex / Dify / Haystack
  Evaluation:      DeepEval / TruLens / Promptfoo / RAGAS
  Fine-tuning:     Unsloth / TRL / PEFT / Axolotl
  Serving:         BentoML / Ray Serve / vLLM / Ollama
  Data:            DVC / Pachyderm / Great Expectations / Label Studio
```

カテゴリを横断して「自分のユースケースに合うツールを選べる」ことが価値。

## SEO 戦略: 競合名でのロングテール

```
検索クエリ例:
  「LangChain 使い方」→ AI大学の LangChain ページに着地
  「Weights&Biases 料金」→ AI大学の W&B ページに着地
  「MLflow vs Kubeflow 比較」→ 比較ページに着地
```

各ツールのページで `/vs-{competitor}` ルートを生成:

```dart
// Flutter: 動的ルーティング
GoRoute(
  path: '/vs-:competitor',
  builder: (context, state) {
    final competitor = state.pathParameters['competitor']!;
    return CompetitorDetailPage(competitorSlug: competitor);
  },
),
```

280社 × SEO ページ = 280のロングテール検索窓口。

## コンテンツ更新戦略

手動更新はスケールしない。GHA Schedule で自動更新:

```yaml
# .github/workflows/ai-university-update.yml
on:
  schedule:
    - cron: '0 */4 * * *'  # 4時間毎

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - name: Fetch latest AI news
        run: |
          # RSS フィードから最新情報を取得
          # Supabase の ai_university_content を更新
```

GitHub Stars / 最新リリース / 価格変更を自動追跡。常に最新の状態を維持。

## 実際の効果

```
AI大学ページ経由のサインアップ: 月 ~50件
平均セッション時間: 4分12秒 (通常ページの2.3倍)
直帰率: 34% (通常ページの58%より低い)
```

「競合情報を調べに来た人」は学習意欲が高く、自分のプロダクトにも興味を持ちやすい。

## うちが学んだこと

```
1. 競合は敵ではなくエコシステムの一部
2. 「競合を網羅している」ことが信頼を生む
3. ユーザーは比較して選ぶ → 比較の場を自分で作る
4. 280社のデータは参入障壁 → 後から追いつきにくい
```

個人開発で「データ資産」を積み上げることが、競合との差別化になる。

## まとめ

競合 280 社をデータベース化した理由:
- **SEO**: 280 のロングテールクエリに応答
- **教育**: ユーザーがAIエコシステムを学べる場所
- **信頼**: 「何でも知っている」プロダクトのブランディング
- **参入障壁**: 280社分のデータ収集・更新は工数がかかる

「競合をコンテンツにする」発想が、自分のニッチを確立する最も効率的な方法だった。
