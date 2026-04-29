-- PS#3 S139: AI大学 373→374社化 — Generative Agents (Stanford / 25エージェント仮想社会 / Park et al. 2023)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'generative-agents', 'overview',
  'Generative Agents (Stanford) — 25エージェント仮想社会・人間らしい行動シミュレーション・記憶+反省+計画 (9/9)',
  $$## Generative Agents とは

**Generative Agents** は **Stanford University** の Joon Sung Park、Joseph C. O'Brien、Carrie J. Cai、Meredith Ringel Morris、Percy Liang、Michael S. Bernstein らが 2023年4月に発表した研究。

**25体の AI エージェント**が仮想の村「Smallville」で生活し、人間らしい社会的行動を見せるという実験で、AI 研究コミュニティに衝撃を与えた。**「シムズ (The Sims) を GPT-4 で動かしたら...」**の直感から生まれた実験。

## Generative Agents の「Smallville」実験

```
仮想の街 Smallville の設定:

  登場エージェント: 25体
  名前の例:
    ・John Lin (薬剤師)
    ・Isabella Rodriguez (カフェオーナー)
    ・Tom Moreno (学校の先生)
    ・Eddy Lin (John の息子・音楽学生)

  環境:
    ・家・職場・公園・図書館・カフェがある街
    ・Sim 風の 2D マップ
    ・各エージェントが毎日の生活を送る

  驚くべき出来事 (実験結果):
    ・バレンタインデーのパーティーを自発的に計画
    ・エージェント同士が自然に会話・友人関係を形成
    ・「今日は図書館に行って研究しよう」と自律判断
    ・噂が広まって行動が変化 (社会的伝播)
```

## Generative Agents のアーキテクチャ

```
3 コンポーネント設計:

  1. Memory Stream (記憶ストリーム):
     ・全経験を時系列で記録
     ・重要度スコアでランキング
     例: "朝食を食べた" (重要度: 1/10)
         "Isabella が来週パーティーを開くと聞いた" (8/10)
         "仕事でミスをして怒られた" (9/10)

  2. Reflection (反省):
     ・定期的に記憶を振り返る
     ・「高次の洞察」を導出
     例: 「最近 John は仕事で忙しそうだ」
         「Isabella は社交的で人気がある」
     ・抽象化された知識として保存

  3. Planning (計画):
     ・記憶と反省を基に1日の計画を立てる
     例: "午前8時: 起床・朝食"
         "午前9時-12時: 薬局で仕事"
         "昼: Eddy と昼食"
         "午後: 研究論文を読む"
         "夕方: Isabella のパーティーに参加"
```

## 記憶の重要度スコアリング

```python
# 記憶の重要度をLLMで評価 (概念的実装)
def calculate_importance(memory_content: str) -> float:
    """
    記憶の重要度を 1-10 で評価
    低い数字 = 日常的な出来事
    高い数字 = 感情的に重要・希少・人生を変える出来事
    """
    response = openai.ChatCompletion.create(
        model="gpt-4",
        messages=[{
            "role": "user",
            "content": f"""
            On a scale of 1 to 10, rate the importance of this memory
            for a person's daily life and long-term plans:

            Memory: {memory_content}

            Rate 1-10 (1=mundane daily activity, 10=life-changing event):
            """
        }]
    )
    return float(response.choices[0].message.content.strip())

# 記憶の取得: Recency + Importance + Relevance の組み合わせ
def retrieve_memories(query: str, all_memories: list, top_k: int = 10):
    """
    関連する記憶を取得 (3要素の加重スコア)
    """
    for memory in all_memories:
        recency = decay_function(memory.timestamp)  # 新しいほど高スコア
        importance = memory.importance_score         # 重要度
        relevance = cosine_similarity(query, memory.content)  # 意味的類似度

        memory.retrieval_score = recency + importance + relevance

    return sorted(all_memories, key=lambda m: m.retrieval_score, reverse=True)[:top_k]
```

## 実験で観察された人間らしい行動

```
Generative Agents が見せた驚くべき振る舞い:

  自発的な社会活動:
    Isabella: 「バレンタインパーティーを開こう！」と計画
    → 他のエージェントに口コミで広まる
    → 当日: 12人以上が参加 (全員が自律的に決定!)
    → エージェントに「パーティーを開いて」と命令しなかった

  感情の変化:
    Tom が仕事でミスをした後、行動が内向きになる
    → 図書館で一人で勉強する時間が増えた
    → 友人との交流が減少

  記憶による関係構築:
    John と Isabella: カフェで偶然会った
    → 翌日: John が「昨日のコーヒーおいしかった」と挨拶
    → 数日後: 常連関係が形成

  情報の社会的伝播:
    「選挙がある」という情報がエージェントに伝わると
    → 投票について話し合い、立候補者を支持する動きが自然発生
```

## Generative Agents が切り開いた研究分野

```
影響を受けた後続研究・応用:

  ゲーム・エンタメ:
    ・NPCが本当に「生きている」ゲームの実現
    ・ストーリーが動的に変化するゲーム設計
    ・Stanford の Stanford Town (後継プロジェクト)

  社会シミュレーション:
    ・政策実験 (この政策を導入したら社会がどう変わるか)
    ・疫病拡散モデル (人間行動付き)
    ・マーケティング: 「この広告が出たら消費者はどう反応するか」

  AI + HCI 研究:
    ・人間と AI の協調作業シミュレーション
    ・組織内での意思決定プロセス研究
    ・教育シミュレーション (教師と生徒の相互作用)

  引用数:
    ・2023年4月発表から数千回引用
    ・CHI 2023 Best Paper Award 受賞
```

## 自分株式会社との関連

Generative Agents の「記憶 + 反省 + 計画」の3層アーキテクチャは、自分株式会社の「日々の自分との対話」機能の設計原型として直接使える。現在の `daily-judgment` EF は1回の判定だが、Generative Agents パターンで「今日の活動記録 (Memory Stream) → 週次の振り返り (Reflection) → 来週の計画 (Planning)」を自動化することで、真の「AI ライフマネジメント」を実現できる。また Memory Stream の重要度スコアリングは、SECOND_BRAIN の memory/ ファイルへの重要度付与メカニズムとして活用できる。
$$,
  'https://github.com/joonspk-research/generative_agents',
  NOW(),
  374
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
