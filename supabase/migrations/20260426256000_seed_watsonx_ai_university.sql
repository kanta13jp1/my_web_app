-- PS#3 S72: AI大学 239→240社化 — IBM watsonx 追加
-- IBM watsonx: エンタープライズAI基盤 / watsonx.ai+data+governance 3製品 / Granite LLM / IBM Japan強 / 規制業種特化

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'watsonx',
  'overview',
  'IBM watsonx — エンタープライズAI基盤 (watsonx.ai+data+governance / Granite LLM / 規制業種特化 / IBM Japan強)',
  $$## IBM watsonx — エンタープライズ AIプラットフォーム

**カテゴリ**: Enterprise AI Platform / Foundation Models / AI Governance / Data & AI
**開発元**: IBM Corporation / 本社: Armonk, New York
**設立**: 2023年5月 (watsonx ブランド統合) / IBMは1911年創業
**製品構成**: watsonx.ai / watsonx.data / watsonx.governance (3製品)
**独自LLM**: Granite シリーズ (Granite-3.0 / Granite-Code 等)
**IBM Japan**: 日本IBMが強力なエンタープライズ販売網を保有
**評価**: 8/9

### 概要
IBM watsonx は **「企業がAIを信頼して本番運用できる」** をテーゼに設計されたエンタープライズAI基盤。2023年5月に従来の Watson ブランドを刷新して登場。特に **金融・医療・政府・通信** などの規制産業において、AIの説明可能性 (XAI)・バイアス検出・監査ログを重視する設計が支持されている。

**日本での強み**: IBM Japanは日本の大手金融機関・製造業・官公庁への長年の販売実績を持ち、watsonx の国内導入事例が急増している。三菱UFJ・SMBC・みずほ・NTTグループなど主要企業が watsonx 採用を表明。

### 製品構成

**watsonx.ai (AI Studio)**
- 基盤モデルの選択・ファインチューニング・推論を統合UI で提供
- 対応モデル: IBM Granite / Llama 2 / Mistral / Flan-T5 / StarCoder 等
- Prompt Lab: プロンプトエンジニアリング専用UI
- AutoAI: ノーコードで ML モデルを自動作成
- Tuning Studio: Few-shot / Instruction Tuning を UI から実行

**watsonx.data (Data Lakehouse)**
- Iceberg / Parquet 形式の統合データ基盤
- Presto / Spark エンジンで SQL クエリ
- データとAIを同一プラットフォームで管理
- オープン規格 (ベンダーロックイン回避)

**watsonx.governance (AI ガバナンス)**
- AIモデルの公平性・ドリフト・説明可能性を自動監視
- EU AI Act / 金融庁ガイドライン / FDA 規制への対応ツール
- モデルのリスクスコアリング・自動アラート
- 監査証跡: いつ・誰が・どのモデルを・どう使ったかを記録

### Granite LLM (IBM独自モデル)

| モデル | パラメータ | 特徴 |
|--------|----------|------|
| Granite-3.0-8B-Instruct | 8B | 汎用指示追従 / Apache 2.0 |
| Granite-3.0-2B-Instruct | 2B | 軽量・エッジ向け |
| Granite-Code-Base-34B | 34B | コード生成特化 |
| Granite-3.2-Vision | マルチモーダル | 文書理解・OCR |

**Granite の特徴**:
- IBM が学習データを完全開示 → 著作権リスクが低い
- Apache 2.0 ライセンス → 商用利用無制限
- 日本語対応 (Granite-3.0 から日本語訓練データ増強)
- 「説明可能AI」設計: なぜその回答をしたか説明可能

### 競合との差別化
| 項目 | IBM watsonx | OpenAI Enterprise | AWS Bedrock | Google Vertex AI |
|------|------------|------------------|------------|-----------------|
| 独自LLM | ✅ Granite | ❌ | ❌ (Amazon Titan) | ✅ Gemini |
| OSS LLM | ✅ Llama/Mistral | ❌ | ✅ | ✅ |
| AI ガバナンス | ✅ 専用製品 | △ | △ | △ |
| オンプレミス | ✅ IBM Cloud Pak | ❌ | ❌ | △ |
| EU AI Act 対応 | ✅ 公式ツール | △ | △ | △ |
| 日本サポート | ✅ IBM Japan強 | ○ | ○ | ○ |
| 価格 | エンタープライズ | エンタープライズ | 従量課金 | 従量課金 |

### 導入コスト
- **IBM Cloud Lite**: 無料トライアル (watsonx.ai Prompt Lab / AutoAI)
- **Essentials**: 月$250〜 / 基本機能 / IBM Cloud上
- **Standard**: 月$1,200〜 / フル機能 / SLA
- **Enterprise**: カスタム価格 / オンプレミス / 専任SE
- **日本IBMサポート**: 国内データセンター利用可 / 日本語SLA

### 自分株式会社での活用可能性
- **競合分析対象**: 自分株式会社の21競合に加え、エンタープライズ市場でのIBM watsonx との競合/棲み分けを把握
- **AI大学コンテンツ**: 規制業種向けAI導入記事でwatsonxをサンプルとして活用
- **将来のエンタープライズ販売**: 自分株式会社が大企業向けに展開する際、watsonx.governance の思想 (AI説明可能性・監査証跡) を参考にプロダクト設計$$,
  NULL,
  NULL,
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'watsonx',
  'api',
  'IBM watsonx API — テキスト生成 / Granite呼び出し / Python SDK / Supabase EF統合',
  $$## IBM watsonx API / 統合

### 概要
watsonx.ai は IBM Cloud 上の REST API と Python SDK (`ibm-watsonx-ai`) を提供。Granite や Llama 2 をプログラムから呼び出せる。

### セットアップ
```bash
pip install ibm-watsonx-ai
```

```bash
export WATSONX_APIKEY="your-ibm-cloud-api-key"
export WATSONX_PROJECT_ID="your-watsonx-project-id"
export WATSONX_URL="https://jp-tok.ml.cloud.ibm.com"  # 東京リージョン
```

### テキスト生成 (Python SDK)
```python
import os
from ibm_watsonx_ai import APIClient, Credentials
from ibm_watsonx_ai.foundation_models import ModelInference
from ibm_watsonx_ai.metanames import GenTextParamsMetaNames as GenParams

credentials = Credentials(
    url=os.environ["WATSONX_URL"],
    api_key=os.environ["WATSONX_APIKEY"],
)
client = APIClient(credentials)
project_id = os.environ["WATSONX_PROJECT_ID"]

# Granite 3.0 でテキスト生成
model = ModelInference(
    model_id="ibm/granite-3-8b-instruct",
    api_client=client,
    project_id=project_id,
    params={
        GenParams.MAX_NEW_TOKENS: 512,
        GenParams.TEMPERATURE: 0.7,
        GenParams.TOP_P: 0.9,
        GenParams.REPETITION_PENALTY: 1.1,
    },
)

def generate_with_granite(prompt: str) -> str:
    """IBM Granite 3.0 でテキストを生成"""
    response = model.generate_text(
        prompt=f"<|user|>\n{prompt}\n<|assistant|>\n"
    )
    return response

# 使用例: CS自動返信 (Granite使用でコスト削減)
answer = generate_with_granite(
    "パスワードリセットの方法を教えてください。"
)
print(answer)
```

### Chat形式 (Messages API)
```python
from ibm_watsonx_ai.foundation_models import ModelInference

chat_model = ModelInference(
    model_id="ibm/granite-3-8b-instruct",
    api_client=client,
    project_id=project_id,
)

messages = [
    {
        "role": "system",
        "content": "あなたは自分株式会社のAIサポート担当です。丁寧な日本語で回答してください。",
    },
    {
        "role": "user",
        "content": "アカウントの削除方法を教えてください。",
    },
]

response = chat_model.chat(messages=messages)
answer = response["choices"][0]["message"]["content"]
print(answer)
```

### REST API 直接呼び出し (TypeScript / Deno Edge Function)
```typescript
// supabase/functions/watsonx-generate/index.ts
// IBM watsonx.ai REST API を Deno から呼び出す

const WATSONX_APIKEY = Deno.env.get("WATSONX_APIKEY")!;
const WATSONX_PROJECT_ID = Deno.env.get("WATSONX_PROJECT_ID")!;
const WATSONX_URL = Deno.env.get("WATSONX_URL") ?? "https://jp-tok.ml.cloud.ibm.com";

async function getIBMToken(): Promise<string> {
  const resp = await fetch(
    "https://iam.cloud.ibm.com/identity/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `grant_type=urn:ibm:params:oauth:grant-type:apikey&apikey=${WATSONX_APIKEY}`,
    },
  );
  const { access_token } = await resp.json();
  return access_token;
}

Deno.serve(async (req: Request) => {
  const { prompt } = await req.json();
  const token = await getIBMToken();

  const genResp = await fetch(
    `${WATSONX_URL}/ml/v1/text/generation?version=2023-05-29`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model_id: "ibm/granite-3-8b-instruct",
        project_id: WATSONX_PROJECT_ID,
        input: `<|user|>\n${prompt}\n<|assistant|>\n`,
        parameters: {
          max_new_tokens: 512,
          temperature: 0.7,
        },
      }),
    },
  );

  const data = await genResp.json();
  const text = data.results?.[0]?.generated_text ?? "";
  return new Response(
    JSON.stringify({ text }),
    { headers: { "Content-Type": "application/json" } },
  );
});
```$$,
  NULL,
  NULL,
  2
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'watsonx',
  'models',
  'IBM watsonx 技術詳細 — Granite アーキテクチャ / AI ガバナンス設計 / EU AI Act対応 / 日本エンタープライズ導入',
  $$## IBM watsonx 技術詳細

### Granite LLM アーキテクチャ

IBM Granite は **「エンタープライズ信頼性」を最優先設計** した LLM ファミリー。

```
[Granite の設計原則]

1. 訓練データの完全開示 (Data Transparency)
   - 使用データセットを IBM が完全開示
   - 著作権侵害リスクが低い → 企業が安心して商用利用可能
   - IBM は訓練データの出典を問われた場合に回答可能

2. Decoder-Only Transformer (LLaMA 互換アーキテクチャ)
   - RoPE (Rotary Position Embedding)
   - FlashAttention 2 による効率化
   - Group Query Attention (GQA) で推論効率向上

3. マルチリンガル設計
   - Granite 3.0: 英語 / ドイツ語 / スペイン語 / フランス語 / 日本語 / ポルトガル語 / アラビア語 等12言語
   - 日本語特化トークナイザー設計 (日本語の分かち書きを考慮)

4. Apache 2.0 ライセンス
   - 商用利用・ファインチューニング・再配布が自由
   - モデルウェイトを自社インフラに持ち込み可能
   - GPT-4 や Claude と異なりオープンソース
```

### watsonx.governance の技術設計

```
[AI ガバナンス監視フロー]

本番AIモデル (例: 融資審査モデル)
       ↓ 推論ログ
watsonx.governance ダッシュボード
  ├── 公平性モニタリング
  │     → 性別 / 年齢 / 地域 別の承認率差異を検出
  │     → EU AI Act Art.10 準拠チェック
  ├── ドリフト検出
  │     → 入力データ分布の変化を統計的に検出
  │     → PSI (Population Stability Index) ≥ 0.2 でアラート
  ├── 説明可能性 (XAI)
  │     → SHAP / LIME で予測根拠を可視化
  │     → 「なぜ融資否決したか」を申請者に説明可能に
  └── 監査証跡
        → いつ・どのモデルv何が・誰に・何と判定したかをログ
        → 金融庁・FDA・EU規制機関への開示用
```

### EU AI Act と IBM watsonx

2024年8月施行の EU AI Act において、watsonx は各条項への対応ツールを提供:

```
EU AI Act リスク分類:
  Unacceptable Risk (禁止): 社会スコアリング / 無差別顔認識
  High Risk (厳格規制): 採用・融資・医療診断・インフラ制御
  Limited Risk (透明性義務): チャットボット / 感情認識
  Minimal Risk: 迷惑メールフィルタ / AIゲーム

watsonx.governance の対応:
  High Risk向け:
    ✅ アルゴリズム差別チェック (Article 10)
    ✅ 技術文書自動生成 (Article 11)
    ✅ 人間による監視ツール (Article 14)
    ✅ 精度・堅牢性・セキュリティテスト (Article 15)
  Limited Risk向け:
    ✅ AIシステムの開示義務自動チェック (Article 52)
```

### 日本エンタープライズ導入事例

| 企業 | 用途 | 成果 |
|------|------|------|
| 三菱UFJ銀行 | 融資審査補助 / コンプライアンス確認 | 審査時間 40% 削減 |
| NTTグループ | 社内ナレッジ検索 / コールセンター支援 | 応答精度 +35% |
| みずほFG | 規制文書解析 / AML (マネロン対策) | 工数 50% 削減 |
| 大手製造業 | 設計文書 Q&A / 品質管理 AI | 設計ミス検出率 2倍 |

### 自分株式会社との関連性

```
現在の競合21社 (notion / moneyforward / etc.) はいずれも SMB〜中堅企業向け。
IBM watsonx は主に大企業 / 規制業種向け。

→ 棲み分け: 自分株式会社は SMB / 個人事業主 / スタートアップに注力
→ 競合ではなくパートナー候補 (将来のエンタープライズ展開時)

AI大学コンテンツとしての価値:
  - 「なぜ大企業はChatGPT APIではなくwatsonxを選ぶのか」を解説
  - EU AI Act 対応の文脈でwatsonxの差別化を理解
  - Granite LLMの Apache 2.0 ライセンスを日本企業がどう活用するか
```$$,
  NULL,
  NULL,
  3
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 239→240社化: IBM watsonx 追加',
  'PS#3 S72。IBM watsonx (エンタープライズAI基盤/watsonx.ai+data+governance 3製品/Granite LLM/Apache 2.0/AI ガバナンス/EU AI Act対応/IBM Japan/日本大手金融採用/8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
