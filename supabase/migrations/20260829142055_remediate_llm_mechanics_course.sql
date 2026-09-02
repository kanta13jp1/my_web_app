-- Tiger remediation #4763: make the LLM mechanics final lesson source-pinned,
-- assessable, and measurable without collecting learner text or identifiers.
-- nocheck: time-relative -- all evidence dates and source revisions are fixed.

update public.ai_university_content
set content = $markdown$
## この完結編の到達目標

**根拠確認日: 2026-08-29 (JST)**

1. tokenがEmbeddingからQ/K/V、Attention重み、文脈化表現、次token予測へ流れる経路を説明できる。
2. Transformerが再帰・畳み込みを使わずAttentionを中心に構成され、系列を並列処理しやすい理由を説明できる。
3. 創発的能力の主張と「評価指標が急な出現を作る場合がある」という反論を区別し、結論の限界を説明できる。

## 読解順序

1. [Wikipedia固定版（revision 1370470611）](https://en.wikipedia.org/w/index.php?title=Large_language_model&oldid=1370470611) のArchitecture節で用語を確認する。百科事典は導入用で、採点対象の核心根拠にはしない。
2. [Attention Is All You Need v7](https://arxiv.org/abs/1706.03762v7) のAbstract、3 Model Architecture、3.2 Attentionを読む。
3. [Emergent Abilities of Large Language Models v2](https://arxiv.org/abs/2206.07682v2) で、創発的能力を小規模モデルからの単純な外挿では予測できない能力として扱う立場を読む。
4. [Are Emergent Abilities of Large Language Models a Mirage? v2](https://arxiv.org/abs/2304.15004v2) で、非線形・不連続な評価指標が見かけの創発を作り得るという反論を読む。

## TransformerとAttentionの情報流

```text
token列
  → Embedding + 位置情報
  → 各tokenから Query / Key / Value を作る
  → QueryとKeyの対応からAttention重みを計算
  → 重み付きでValueを集約し、他tokenの文脈を取り込む
  → Multi-Head出力、残差接続、正規化、Feed-Forward
  → 語彙上の確率分布から次tokenを予測
```

原論文のTransformerは、再帰と畳み込みを使わずAttentionを中心に系列変換を構成しました。これは「モデルが意味を人間と同じように理解する」という証明ではなく、token間の依存を学習可能な重みとして計算する仕組みです。

## 創発性は結論ではなく測定論争

- **創発を支持する見方**: 一部の能力は小さいモデルでは見えず、規模を増やしたときに現れ、単純な性能曲線から予測しにくい。
- **測定依存性の反論**: exact-matchのような不連続指標では急に能力が現れたように見えても、連続指標では滑らかな改善として見える場合がある。
- **この講座での結論**: 「創発は常に実在する／常に錯覚である」と断定しない。モデル、課題、prompt、指標、閾値を明示して比較する。

## 10分概念マップ課題と採点基準

手元の紙またはローカルメモに、次の2本を1枚で結んでください。

- `token → Q/K/V → Attention重み → 文脈化表現 → 次token予測`
- `規模拡大 → 能力測定 → 創発という解釈 ↔ 指標依存という反論`

各1点、合計3点です。

1. **情報流**: QとKが重みに、Vが集約される情報に対応することを矢印で示す。
2. **統合**: Attentionの出力がTransformer層のFeed-Forwardや残差接続を経て次token予測につながることを示す。
3. **限界**: 創発性の主張と測定依存性の反論を併記し、評価指標を確認する必要を明記する。

下の3問、課題完了申告、5段階自己評価を送ると、図・回答本文・個人情報を保存せず、閲覧数、完了数、正答数、自己評価だけを匿名集計します。
$markdown$,
    source_url =
      'https://en.wikipedia.org/w/index.php?title=Large_language_model&oldid=1370470611',
    published_at = date '2026-08-29',
    target_audience =
      'Transformer、Attention、創発性を一次資料と測定上の限界から統合して学びたい開発者・研究学習者',
    observable_learning_outcome =
      'Attentionの情報流を図示し、Transformerの構成と創発性の主張・測定依存性の反論を区別して説明できる',
    assessment_verification_method =
      '3点の概念マップrubric、3問の確認問題、課題完了申告、5段階自己評価を匿名集計する',
    evidence_source_url = 'https://arxiv.org/abs/1706.03762v7',
    evidence_verified_at = timestamptz '2026-08-29 00:00:00+09'
where provider = 'academic'
  and category = 'llm_mechanics';

alter table public.ai_university_learning_outcome_events
  drop constraint if exists ai_university_learning_outcome_task_identity;
alter table public.ai_university_learning_outcome_events
  add constraint ai_university_learning_outcome_task_identity check (
    (task_version = '01ai_latest_20260828_v1' and provider = '01ai' and category = 'news')
    or (task_version = '01ai_models_20260829_v1' and provider = '01ai' and category = 'models')
    or (
      task_version = 'academic_llm_mechanics_20260829_v1'
      and provider = 'academic'
      and category = 'llm_mechanics'
    )
  );

drop policy if exists "anonymous clients insert bounded learning outcomes"
  on public.ai_university_learning_outcome_events;
create policy "anonymous clients insert bounded learning outcomes"
  on public.ai_university_learning_outcome_events
  for insert
  to anon, authenticated
  with check (
    (
      (task_version = '01ai_latest_20260828_v1' and provider = '01ai' and category = 'news')
      or (task_version = '01ai_models_20260829_v1' and provider = '01ai' and category = 'models')
      or (
        task_version = 'academic_llm_mechanics_20260829_v1'
        and provider = 'academic'
        and category = 'llm_mechanics'
      )
    )
    and (
      (event_name = 'task_viewed' and correct_answers is null and total_questions is null and self_rating is null)
      or (
        event_name = 'task_completed'
        and correct_answers between 0 and 3
        and total_questions = 3
        and self_rating between 1 and 5
      )
    )
  );
