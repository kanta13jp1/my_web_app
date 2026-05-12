---
title: "LLM プロンプトエンジニアリング実践 — CoT / Few-shot / System Prompt の設計"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# LLM プロンプトエンジニアリング実践 — CoT / Few-shot / System Prompt の設計

「思ったとおりの答えが返ってこない」を解消する。実際の個人開発での実践例を中心に解説する。

## なぜプロンプト設計が重要か

```
同じモデル・同じ質問でも:
  プロンプト設計 悪: 「まあまあの回答」
  プロンプト設計 良: 「期待を超える回答」

コスト差:
  haiku + 優れたプロンプト vs sonnet + 雑なプロンプト
  → 品質同等で 4倍のコスト差が生まれることがある
```

## 1. System Prompt: モデルの「役割」を明確に

```python
# ❌ NG: 役割が曖昧
system = "あなたはAIアシスタントです。"

# ✅ OK: 具体的な役割 + 制約 + 出力形式
system = """あなたは個人開発者向けの生産性コーチです。

## あなたの役割
- 1日のタスク優先順位をつける
- 集中を妨げる要因を特定する
- 実行可能な改善提案をする

## 回答ルール
- 提案は最大3つ (それ以上は混乱を生む)
- 技術的すぎる用語は避ける
- 「〜してみてください」形式で締める

## 回答しないこと
- 医療・法律・投資アドバイス
- ユーザーの行動を批判する言い方"""
```

**Claude API での設定**:

```python
response = client.messages.create(
  model="claude-haiku-4-5",
  system=system,  # system パラメータに設定
  messages=[{"role": "user", "content": user_input}]
)
```

## 2. Chain of Thought (CoT): 推論ステップを明示させる

```python
# ❌ NG: 直接答えを求める (複雑な判断が雑になる)
prompt = "このタスクは今日中にやるべきか判断して"

# ✅ OK: 考える手順を指示する
prompt = """以下のタスクを評価してください。

タスク: {task}

判断手順:
1. 締め切りを確認 (今日か / 今週か / 来週以降か)
2. 影響範囲を確認 (自分だけか / 他者への影響があるか)
3. 所要時間を見積もる (15分以内か / 1時間以上か)
4. 上記を踏まえて: 今日やる / 今週やる / 後回しにする を選ぶ

各手順を考えてから最終判断を出してください。"""
```

**CoT が効果的なケース**:

```
✅ 複数条件が絡む判断
✅ 数学・論理推論
✅ コードのバグ解析
✅ 文章の品質評価

❌ CoT が不要なケース:
  単純な分類 (感情分析など)
  短文生成
  → haiku + シンプルプロンプトで十分
```

## 3. Few-shot: 例示で出力形式を固定する

```python
# ❌ NG: 形式を説明するだけ
prompt = "タスクを3段階の優先度に分類してください。"

# ✅ OK: 例を見せる
prompt = """タスクを優先度分類してください。

例:
入力: 「確定申告の書類を集める (期限: 3月15日)」
出力: 優先度: 高 | 理由: 期限固定・行政手続き | 今日のアクション: 源泉徴収票を探す

入力: 「本棚を整理する」
出力: 優先度: 低 | 理由: 期限なし・影響小 | 今日のアクション: 後回しリストに追加

では以下を分類してください:
入力: {task}
出力:"""
```

## 4. Prompt Caching で大幅コスト削減

```python
# 長いシステムプロンプトをキャッシュ
messages = [
  {
    "role": "user",
    "content": [
      {
        "type": "text",
        "text": long_system_prompt,  # 2000トークン以上のプロンプト
        "cache_control": {"type": "ephemeral"}
      },
      {
        "type": "text",
        "text": user_input
      }
    ]
  }
]

# 初回: 通常コスト
# 2回目以降: キャッシュhit → 入力コスト 90% 削減
# 5分以内のリクエストに有効
```

## プロンプトのバージョン管理

```python
# prompts.py でプロンプトをコード化
PRODUCTIVITY_COACH_V2 = """
あなたは...
[v2: 出力形式を JSON に変更]
"""

# テスト: promptfoo / TruLens で品質を定量化
# promptfoo.yaml
prompts:
  - id: v1
    raw: "{{PRODUCTIVITY_COACH_V1}}"
  - id: v2
    raw: "{{PRODUCTIVITY_COACH_V2}}"

tests:
  - vars:
      task: "プレゼン資料を作る"
    assert:
      - type: contains
        value: "優先度"
```

## まとめ

```
役割・制約・形式を明確に → System Prompt
複雑な判断をさせる      → Chain of Thought
出力形式を固定する      → Few-shot 例示
コスト削減              → Prompt Caching (cache_control)
品質管理                → promptfoo / TruLens でバージョン管理
```

プロンプトエンジニアリングは「モデルへの仕様書作成」。明確なシステムプロンプト + 少数の例示が、長い説明より常に効果的。

