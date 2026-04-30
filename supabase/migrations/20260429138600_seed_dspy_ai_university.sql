-- PS#3 S134: AI大学 363→364社化 — DSPy (Stanford / LLMプログラミング / 自動プロンプト最適化)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'dspy', 'overview',
  'DSPy (Stanford) — LLM プログラミングフレームワーク・自動プロンプト最適化・宣言的AI構築 (9/9)',
  $$## DSPy とは

**DSPy** (Declarative Self-improving Language Programs) は Stanford University の **Omar Khattab** らが開発した革命的な LLM プログラミングフレームワーク。「プロンプトを手書きする」時代を終わらせ、**プログラムを書けばプロンプトが自動最適化**される未来を提示している。

2024年の AI エンジニアリング界で最も注目を集めた研究成果の一つ。

## DSPy の革命的なコンセプト

```
従来の LLM 開発:

  エンジニア → プロンプト手書き → LLM → 出力
  ↑ プロンプトの微妙な変更で結果が大きく変わる
  ↑ モデルが変わるたびにプロンプトを書き直す
  ↑ 最適なプロンプトを見つけるのに時間がかかる

DSPy の世界:

  エンジニア → プログラム (Python) → DSPy が自動最適化 → LLM → 出力
  ↑ プロンプトは DSPy が自動生成・改善
  ↑ モデルが変わっても自動再最適化
  ↑ 評価指標を定義すれば DSPy が最良プロンプトを探索
```

## DSPy のプログラミングモデル

```python
import dspy

# LLM の設定
lm = dspy.LM("openai/gpt-4o", max_tokens=1000)
dspy.configure(lm=lm)

# Signature (入出力の型定義)
class QASignature(dspy.Signature):
    """質問に答えてください。"""
    question: str = dspy.InputField()
    answer: str = dspy.OutputField(desc="簡潔な回答")

# Module (処理の定義)
class SimpleQA(dspy.Module):
    def __init__(self):
        self.qa = dspy.ChainOfThought(QASignature)

    def forward(self, question):
        return self.qa(question=question)

# 使用
qa = SimpleQA()
result = qa(question="Supabase とは何ですか？")
print(result.answer)
```

## 自動最適化の仕組み

```python
# トレーニングデータを用意
trainset = [
    dspy.Example(
        question="Supabaseとは？",
        answer="PostgreSQLベースのBaaSサービス"
    ),
    # ... 数十〜数百件
]

# 評価指標を定義
def validate_answer(example, pred, trace=None):
    return example.answer.lower() in pred.answer.lower()

# 最適化器でプログラムを改善
from dspy.teleprompt import BootstrapFewShot

optimizer = BootstrapFewShot(
    metric=validate_answer,
    max_bootstrapped_demos=4
)

# 自動最適化を実行 (プロンプトを自動生成)
optimized_qa = optimizer.compile(
    SimpleQA(),
    trainset=trainset
)

# 最適化されたプログラムを使用
result = optimized_qa(question="Flutterとは？")
```

## DSPy の主要コンポーネント

```
DSPy のビルディングブロック:

  Signatures (宣言):
    ・入力・出力の型と説明を定義
    ・プロンプトの「意味」を表現

  Modules (処理):
    ・Predict: シンプルな呼び出し
    ・ChainOfThought: 段階的推論
    ・ReAct: エージェント的推論
    ・Retrieve: ベクトル検索統合

  Optimizers (最適化):
    ・BootstrapFewShot: Few-shot 例を自動選択
    ・MIPRO: 命令文を自動改善
    ・BayesianSignatureOptimizer: ベイズ最適化
```

## なぜ DSPy が重要か

1. **モデル非依存**: GPT-4 → Claude → Gemini に切り替えても自動再最適化
2. **再現性**: 同じデータ・同じコードで同じ結果 (プロンプトアートに依存しない)
3. **可観測性**: プログラムの各ステップが追跡可能
4. **研究から実用へ**: Stanford の ML 手法をアプリ開発に適用

## 自分株式会社との関連

DSPy の「プログラムを書けばプロンプトが自動最適化」哲学は、自分株式会社の AI 開発の将来方向性と直結。現在 CLAUDE.md や inject-rules.txt でプロンプトを手書きしているが、DSPy を活用すれば「評価指標を定義して自動最適化」に移行できる。特に ai-hub EF の各 action に DSPy を適用することで、CS 返信・競合分析・AI大学コンテンツ生成の品質を自動改善できる。
$$,
  'https://github.com/stanfordnlp/dspy',
  NOW(),
  364
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
