-- PS#3 S128: AI大学 351→352社化 — Agentless (バグ修正の最小エージェント / MIT / SWE-bench簡潔設計)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'agentless', 'overview',
  'Agentless — 最小構成バグ修正エージェント・エージェントレス設計哲学・SWE-bench高効率 (9/9)',
  $$## Agentless とは

**Agentless** はイリノイ大学 (UIUC) が開発した、その名の通り「エージェントフレームワークを使わない」シンプルなバグ修正ツール。複雑なエージェントループを排除し、**3フェーズの直線的なパイプライン**でバグ修正を実現する。

「エージェントは複雑すぎる。シンプルなパイプラインで十分な結果が出る」という設計思想が特徴。

## 設計哲学: エージェントレスとは何か

```
従来のエージェントアプローチ:

  LLM ←→ Tool1 (bash)
  LLM ←→ Tool2 (file edit)
  LLM ←→ Tool3 (test run)
  ... (ループ / 再計画 / 多段決定)

Agentless アプローチ:

  Phase 1: Localization (ファイル特定)
  Phase 2: Repair (パッチ生成)
  Phase 3: Validation (テスト検証)

  ↑ 直線的・決定論的・再現可能
```

**なぜエージェントレスか**:
- エージェントループは不確実性が高い
- 中間ステップのエラーが累積する
- デバッグが困難
- コストが予測しにくい

Agentless は各フェーズを独立させることで、どこで失敗したかを明確にする。

## 3フェーズアーキテクチャ

```
Phase 1 — ファイル局所化 (Localization):

  入力: GitHub Issue テキスト
  処理:
    1. コードベース構造を LLM に提示
    2. 「どのファイルが関係するか?」を質問
    3. 関連ファイルのリストを取得
  出力: 関係ファイル TOP-K リスト

Phase 2 — パッチ生成 (Repair):

  入力: Phase 1 の関連ファイル + Issue
  処理:
    1. 関連コードを LLM に提示
    2. 複数のパッチ候補を生成 (N サンプル)
    3. パッチの多様性を確保
  出力: N 個のパッチ候補

Phase 3 — 検証 (Validation):

  入力: N 個のパッチ候補 + テストスイート
  処理:
    1. 各パッチをテストで評価
    2. テスト通過率でランキング
    3. 最良パッチを選択
  出力: 最終パッチ
```

## SWE-bench での実績

```
Agentless の SWE-bench Full 結果 (GPT-4o 使用):

  解決率: ~27-30% (SWE-bench Full)
  コスト: $0.34/issue (GPT-4o 使用時)
  速度: 約 5 分/issue

  比較:
  - AutoCodeRover (ACR-2): ~52% (Verified)
  - SWE-agent: ~53% (Verified)
  - Agentless: ~30% (Full = より難しいベンチマーク)

  ※ SWE-bench Full は Verified より問題数が多く難しい
  ※ シンプルな実装にしては高い解決率
```

## 実装のシンプルさ

```bash
# セットアップ (Python のみ)
git clone https://github.com/OpenAutoCoder/Agentless
pip install -r requirements.txt

# 実行例
export OPENAI_API_KEY=sk-...
python agentless/fl/localize.py \
  --output_folder results/ \
  --model gpt-4o \
  --issue_link https://github.com/org/repo/issues/123

python agentless/repair/repair.py \
  --output_folder results/ \
  --model gpt-4o

python agentless/validation/validate.py \
  --output_folder results/
```

## Agentless から学ぶ設計原則

1. **KISS原則 (Keep It Simple)**: 複雑なエージェントが必ずしも良い結果を出すわけではない
2. **フェーズ独立性**: 各フェーズを疎結合にして問題の特定を容易にする
3. **並列サンプリング**: 1つの最良パッチより N 個のパッチ候補を生成してランキング
4. **コスト効率**: エージェントループを減らすことでAPI呼び出しコストを削減

## 自分株式会社との関連

Agentless の「Phase 1: Localize → Phase 2: Repair → Phase 3: Validate」の3段階パイプラインは、自分株式会社の AI 機能設計に応用できる。特に GitHub Issue から修正コードを自動生成する `github-issue-fix.yml` GHA ワークフローの改善に、Agentless の Localization フェーズのアルゴリズム（コードベース構造提示 → 関連ファイル特定）が直接活用できる。
$$,
  'https://github.com/OpenAutoCoder/Agentless',
  NOW(),
  352
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
