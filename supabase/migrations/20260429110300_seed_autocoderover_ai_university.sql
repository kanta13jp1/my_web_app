-- PS#3 S128: AI大学 350→351社化 — AutoCodeRover (LLM自律バグ修正 / ACR-2 / SWE-bench 52%+)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'autocoderover', 'overview',
  'AutoCodeRover — LLM自律バグ修正エージェント・SWE-bench最高水準・コンテキスト圧縮技術 (9/9)',
  $$## AutoCodeRover とは

**AutoCodeRover** はシンガポール国立大学 (NUS) と **Alibaba DAMO Academy** が共同開発した自律バグ修正エージェント。**SWE-bench** ベンチマークで高スコアを記録し、学術界から産業界へ橋を架けるオープンソースツール。

ACR (AutoCodeRover) は GitHub Issue の説明文を読み込み、関連コードを特定・パッチを生成・テストで検証する一連のプロセスを完全自動化する。

## SWE-bench 競争での位置づけ

```
SWE-bench Verified スコア比較 (2025年時点):

  AutoCodeRover v2 (ACR-2):      ~52%+ (学術系最高水準)
  Cosine Genie:                  ~55%+ (商用ウェイトリスト)
  OpenHands + Claude:            53%
  SWE-agent (Princeton):         ~53%

  ※ 学術OSS系では最高水準クラス
  ※ 商用クローズドと比較しても遜色なし
```

## AutoCodeRover の技術的特徴

```
AutoCodeRover アーキテクチャ:

  Phase 1 — Context Retrieval:
    ・GitHub Issue 文章を解析
    ・関連ファイル・クラス・メソッドを特定
    ・抽象構文木 (AST) を活用したコード理解
    ・セマンティック検索でコンテキスト圧縮

  Phase 2 — Patch Generation:
    ・LLM (GPT-4 / Claude) にコンテキスト送信
    ・最小限の変更でバグを修正
    ・複数の候補パッチを生成

  Phase 3 — Verification:
    ・テストスイートで修正を検証
    ・失敗時は Context Retrieval からやり直し
    ・最大 N 回イテレーション
```

## コンテキスト圧縮の革新

```python
# AutoCodeRover のコンテキスト管理 (概念コード)

class ContextRetriever:
    def get_relevant_context(self, issue: str) -> str:
        # 1. Issue からキーワード抽出
        keywords = self.extract_keywords(issue)

        # 2. AST ベースで関連コードを検索
        relevant_files = self.ast_search(keywords)

        # 3. コンテキストウィンドウに収まるよう圧縮
        compressed = self.compress_context(
            relevant_files,
            max_tokens=4096  # LLMのコンテキスト制限
        )
        return compressed
```

**なぜコンテキスト圧縮が重要か**: 大規模コードベースはLLMのコンテキストウィンドウに収まらない。AutoCodeRover は AST 解析で関連箇所のみを抽出し、無関係なコードを排除する。

## AutoCodeRover vs SWE-agent

| 項目 | AutoCodeRover | SWE-agent |
|------|--------------|-----------|
| アプローチ | コンテキスト圧縮 + AST | エージェントループ |
| 機関 | NUS + Alibaba | Princeton |
| ライセンス | Apache-2.0 | MIT |
| 特徴 | 学術的厳密性 | 汎用性 |
| SWE-bench | ~52% (ACR-2) | ~53% (Claude) |

## セットアップ例

```bash
# インストール
git clone https://github.com/nus-apr/auto-code-rover
cd auto-code-rover
pip install -e .

# 環境変数
export OPENAI_API_KEY=sk-...  # or ANTHROPIC_API_KEY

# GitHub Issue に対して実行
python app/main.py \
  --model gpt-4o \
  --issue-link https://github.com/org/repo/issues/123 \
  --output-dir ./patches
```

## 自分株式会社との関連

AutoCodeRover の「AST + セマンティック検索でコンテキストを圧縮してバグ修正」アーキテクチャは、自分株式会社の memory-search-hub EF (SECOND_BRAIN #7) の設計に直接応用できる。大きなコードベースから関連箇所のみを抽出してLLMに渡す手法は、トークン効率向上の鍵。
$$,
  'https://github.com/nus-apr/auto-code-rover',
  NOW(),
  351
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
