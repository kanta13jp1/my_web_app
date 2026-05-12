-- PS#3 S152: AI大学 LLM理論 追加 (Issue #1854)
-- Source: NotebookLM 2eb9f737 The Mechanics of Prediction: Inside LLMs

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'academic', 'llm_mechanics',
  'LLM理論：大規模言語モデルの仕組み — Transformer・Attention・創発的現象 完全解説 (10/10)',
  $$## LLM (大規模言語モデル) とは

**Large Language Model (LLM)** は本質的に「テキストの次に来る単語を予測する、
洗練された数学的関数」。Claude / GPT-4 / Gemini はすべてこの原理で動作する。

重要な理解: LLMは確率的 — 常に1つの答えを返すのではなく、
確率が低い単語も選択することで**多様で自然な出力**を実現する。

## 学習プロセス

```
Step 1: プレトレーニング (事前学習)
  → インターネット上の膨大なテキスト (人間が 2600年読み続けても追いつかない量)
  → 「次の単語を予測」させて誤差を計算
  → バックプロパゲーション (誤差逆伝播) でパラメータを微調整
  → これを何兆回繰り返す → GPU 必須 (並列計算に特化)

Step 2: RLHF (人間フィードバックによる強化学習)
  → インターネット文章予測だけでは「良いアシスタント」にならない
  → 人間が回答を評価 → 好ましい回答を生成するようパラメータ追調整
  → Claude / ChatGPT が「役立つ」「安全」「誠実」になる理由

Step 3: パラメータ = 動作の全て
  → 数千億個の連続数値 (ウェイト) に全知識が埋め込まれる
  → "学習" = このウェイトを最適化するプロセス
```

## Transformer アーキテクチャ

```
2017年: Google の「Attention Is All You Need」論文が革新をもたらした

[旧: RNN] テキストを1単語ずつ順番に処理 → 並列化不可・長文で記憶喪失
[新: Transformer] 文章全体を一度に並行処理 → GPU で超高速学習可能

Transformer の処理フロー:
  1. ベクトル化 (Embedding)
     → 各単語を「長い数字のリスト (ベクトル)」に変換
     → 意味を数値空間にエンコード

  2. Self-Attention (自己注意機構) ← 最重要
     → 各単語が文章内の他の全単語と「情報交換」
     → 例: "bank" が "river" の近くにあれば「川岸」の意味に調整
     → これにより文脈を理解した意味表現が得られる

  3. Feed-Forward Neural Network
     → 学習中に得た言語パターンを記憶・強化
     → Attention の結果をさらに変換

  4. 次の単語予測
     → 最終的な数値表現から確率分布を計算
     → サンプリングで次の単語を選択
```

## 創発的現象 (Emergence)

```
研究者が設計するのは「枠組み」だけ:
  → Transformer アーキテクチャ
  → Attention 機構
  → 損失関数とバックプロパゲーション

「なぜこれほど正確か」は解明されていない:
  → 数千億パラメータ × 膨大データの相互作用から生じる「創発」
  → 数学・プログラミング・推論能力が突然現れる閾値現象
  → 研究者自身も驚く能力の出現

自分株式会社への示唆:
  → Claude / GPT-4 の振る舞いは「設計通り」ではなく「創発的」
  → 予期しない高能力 (翻訳・コード生成) も予期しない失敗 (幻覚) も同原理
  → AI_CHARACTER_PRINCIPLES.md の「AI の能力限界理解」に反映
```

## スケーリング則 (Scaling Laws)

| モデルサイズ | 学習データ | 計算量 | 能力 |
|------------|-----------|--------|------|
| 小 (7B) | 1T tokens | 低 | 基本タスク |
| 中 (70B) | 2T tokens | 中 | 複雑推論可 |
| 大 (175B+) | 5T+ tokens | 高 | 創発的能力出現 |
| 最大 (1T+) | 20T+ tokens | 超大 | AGI水準議論 |

- **OpenAI Scaling Law**: モデルサイズ × データ量 × 計算量 が等比増加で性能向上
- **中国系モデルの効率化**: DeepSeek-R1 等、少ないパラメータで高性能を実現
- **示唆**: 能力向上は「データ + 計算」の掛け算 — 自前学習よりAPI活用が費用対効果高

## 自分株式会社 AI 大学での位置づけ

### Claude / GPT-4 の能力・限界の理解 (開発者必修)

```
幻覚 (Hallucination) のメカニズム:
  → 「確率的に最もらしいテキスト生成」≠「事実の確認」
  → Supabase DB からのリアルデータ取得 + LLM 生成の組み合わせが必須
  → self.project の [REAL-DATA] ルールの理論的根拠

コンテキストウィンドウの制約:
  → Attention は全トークン間の計算 → O(n²) のメモリ/計算コスト
  → 長いコンテキスト = 速度低下・コスト増大
  → CLAUDE.md の MAX_MCP_OUTPUT_TOKENS 設定の理論的根拠

Prompt Caching の効果:
  → 同じプレフィックスは KV キャッシュで再利用 → コスト 90% 削減
  → Claude API の Prompt Caching Beta = Anthropic の差別化戦略
```

- **学部**: 学術研究学部 (academic_research)
- **学科**: LLM理論・アーキテクチャ学科 (llm_mechanics)
- **関連プロバイダー**: ml_engineering / academic / claude / openai
- **実用的示唆**: LLMの仕組みを理解することで、Supabase RAG設計・Prompt設計・
  コスト最適化の判断が技術的根拠に基づいて行えるようになる。
$$,
  'https://en.wikipedia.org/wiki/Large_language_model',
  '2026-01-01',
  103
)
ON CONFLICT (provider, category) DO NOTHING;
