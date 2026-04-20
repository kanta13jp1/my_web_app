-- Session PS#3-S21: AI大学 139 社化 — Snorkel AI 追加
-- Snorkel AI = Stanford DAWN lab 発 weak supervision 発明者 Alex Ratner 創業
-- Snorkel Flow + GenFlow + Evaluate + Expert Data-as-a-Service の 4 本柱
-- $238M 累計 / Series D $100M at $1.3B valuation (2025-05, Addition lead)
-- Step 0: 8.5/9 (OSS 部分公開 snorkel Python lib / Flow platform 非公開)

INSERT INTO ai_university_content (provider, category, title, content, updated_at)
VALUES
  (
    'snorkel_ai',
    'overview',
    'Snorkel AI — weak supervision 発明者による「data-first AI」ラボ',
    $md$
# Snorkel AI — weak supervision 発明者による「data-first AI」ラボ

2019 年スタンフォード大 DAWN lab からスピンオフ、CEO **Alex Ratner**
(スタンフォード PhD / weak supervision 原論文筆頭著者) が率いる企業向け
AI データ開発プラットフォーム。「モデルは commodity、差別化はデータ」思想。

## 既存 138 社との差別化
| 観点 | Snorkel AI | Scale AI | Hugging Face |
|------|-----------|----------|--------------|
| 思想 | 🏷️ weak supervision (プログラマティック ラベリング) | 人間アノテーション大規模化 | モデル hub |
| 出自 | Stanford DAWN lab (2016 原論文) | コンシューマ labeling | OSS community |
| ターゲット | エンタープライズ fine-tune / RAG 評価 | 自動運転 + LLM 訓練 | 開発者 |
| 核技術 | labeling functions → 確率的 label | 人手 + AI assist | model hosting |
| 創業 | 2019-04 (Stanford spin-off) | 2016 | 2016 |

## 主要プロダクト (4 本柱)
- **Snorkel Flow**: weak supervision ベースの label 生成 + model 訓練プラットフォーム
- **Snorkel GenFlow** (2024-2025): LLM 向け instruction/SFT データセット生成
- **Snorkel Evaluate**: LLM/Agent 評価ベンチマーク自動生成
- **Snorkel Expert Data-as-a-Service**: 業種エキスパートによる高品質 dataset 供給

## 資金調達
- 2019 Seed: $15M
- 2020 Series A: $35M (GV lead)
- 2021 Series B: $35M (Lightspeed)
- 2021 Series C: \$85M at **\$1B valuation** (Addition lead)
- 2025-05 Series D: **\$100M at \$1.3B valuation** (Addition lead, 累計 \$238M)

## 市場文脈 (Gartner)
- 2026 までに「scalable data practice なし」の AI プロジェクトの **60% が放棄される**
- → Snorkel の提供する programmatic data layer が enterprise 必須化する予測

## 自分株式会社での活用
- daily-judgment: labeling functions で自分の過去判断を弱監督データ化 → 未来判断の fine-tune
- AI大学: GenFlow で 139 provider の差別化 instruction dataset 自動生成
- user-manual: Evaluate で ai-hub routing の quality regression 自動検知
$md$,
    NOW()
  ),
  (
    'snorkel_ai',
    'models',
    'Snorkel Flow / GenFlow / Evaluate / Expert DaaS — 4 プロダクト詳解',
    $md$
# Snorkel Flow / GenFlow / Evaluate / Expert DaaS — 4 プロダクト詳解

## Snorkel Flow (主力プラットフォーム)
- **Labeling Functions**: Python 関数で「これはスパム」「これは契約書」を宣言的に表現
- **Label Model**: 複数 LF の弱い label を確率的に統合 (Snorkel MeTaL アルゴリズム)
- **訓練**: 統合 label で downstream モデル fine-tune
- 効果: 人手 labeling 比 **10-100x 高速** (Stanford 論文で実証)

## Snorkel GenFlow (生成 AI 向け)
- LLM の instruction-tuning / SFT 用 dataset を programmatic に生成
- 用途: 業種特化 chatbot / RAG / agent の fine-tune データ自作
- 既存 open instruct dataset (Alpaca 等) との違い = 自社ドメイン知識を LF で注入可能

## Snorkel Evaluate
- LLM/Agent の評価ベンチマークを自動生成 (rubric-based)
- hallucination / compliance / safety の regression 検知
- Anthropic Claude / OpenAI GPT / Mistral / 自社モデルを横断比較可能

## Snorkel Expert Data-as-a-Service
- 業種エキスパート (医師 / 弁護士 / 金融アナリスト) を Snorkel が調達
- 顧客の private data を expert が labeling → GenFlow で scale up
- 「少数の高品質 seed + programmatic expansion」パターン

## OSS: snorkel Python library
- GitHub: github.com/snorkel-team/snorkel
- Apache 2.0 / 5.9k+ ⭐ / labeling function + label model のコア OSS 公開
- 商用プラットフォーム (Flow) は proprietary

## 料金
- OSS snorkel: 無料 (Apache 2.0)
- Snorkel Flow: **enterprise custom** (年間 契約 / SaaS or VPC)
- Expert DaaS: プロジェクト見積もり

## Philosophy (Ratner 公言)
> "The bottleneck in enterprise AI isn't compute, it's data. We turn a
> month of hand-labeling into a day of labeling function coding."
$md$,
    NOW()
  ),
  (
    'snorkel_ai',
    'api',
    'snorkel OSS + Snorkel Flow SDK — 自分株式会社での組込手順',
    $md$
# snorkel OSS + Snorkel Flow SDK — 自分株式会社での組込手順

## OSS snorkel 最小導入
```bash
pip install snorkel
```

## Labeling Function 例 (daily-judgment 分類)
```python
from snorkel.labeling import labeling_function, PandasLFApplier
from snorkel.labeling.model import LabelModel

ABSTAIN = -1
GOOD_JUDGMENT = 0
RISKY_JUDGMENT = 1

@labeling_function()
def lf_has_philosophy_keyword(row):
    # 9 原則キーワード含有 → 良い判断
    keywords = ["ユーザー価値", "長期", "昨日の自分", "資本=時間"]
    return GOOD_JUDGMENT if any(k in row.text for k in keywords) else ABSTAIN

@labeling_function()
def lf_has_risk_signal(row):
    # 短期的 / 衝動 → risky
    signals = ["すぐ", "今だけ", "限定"]
    return RISKY_JUDGMENT if any(s in row.text for s in signals) else ABSTAIN

# 過去 memory/ を読み込んで LF 適用
import pandas as pd
df = pd.DataFrame({"text": [...]})  # memory/project_*.md 本文
L = PandasLFApplier([lf_has_philosophy_keyword, lf_has_risk_signal]).apply(df)

# 確率的 label 生成
label_model = LabelModel(cardinality=2)
label_model.fit(L)
probs = label_model.predict_proba(L)
# → 「過去判断の 68% が PHILOSOPHY 準拠」等の弱監督集計
```

## Snorkel Flow (enterprise)
```python
from snorkel.flow import SnorkelFlowClient
client = SnorkelFlowClient(api_key=os.getenv("SNORKEL_FLOW_API_KEY"))

dataset = client.datasets.create("jibun-inc-memory")
dataset.upload("memory/*.md")

# GenFlow で instruction dataset 生成
gen = client.genflow.create(
    name="jibun-philosophy-sft",
    seed_dataset=dataset.id,
    instruction="自分株式会社 9 原則に照らして過去判断を評価せよ",
)
gen.run()  # → Alpaca 形式 SFT dataset を自動生成
```

## ai-hub 統合提案 (Win版 cross-instance-pr 候補)
```typescript
// supabase/functions/ai-hub/index.ts に追加
case 'data.weak_supervision':
  // labeling_functions[] + texts[] を受け取り Snorkel LabelModel 呼び出し
  // 確率的 label を返却 / AI-DEV-23 原則 3 (trace_id + 5秒超検出)
  return await snorkelWeakSupervision(body);

case 'data.evaluate_model':
  // 複数 LLM 応答を Snorkel Evaluate rubric で scoring
  // hallucination/compliance/safety の 3 軸 score 返却
  return await snorkelEvaluate(body);
```

## 試す
- Web: https://snorkel.ai/
- OSS GitHub: https://github.com/snorkel-team/snorkel
- ドキュメント: https://docs.snorkel.ai/
- 原論文 (Ratner et al., VLDB 2017): https://arxiv.org/abs/1711.10160
- Snorkel Flow 資料請求: https://snorkel.ai/demo/

## Gartner 引用
- 2026 までに scalable data practice なしの AI プロジェクトの 60% が放棄
  (出典: snorkel.ai/blog/series-d)
$md$,
    NOW()
  )
ON CONFLICT (provider, category) DO UPDATE
SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
