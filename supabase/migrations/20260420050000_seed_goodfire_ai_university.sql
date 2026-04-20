-- PS版#3 Session 12: Goodfire — AI Interpretability ($1.25B valuation)
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'goodfire',
  'overview',
  'Goodfire — AI Interpretability の最前線 ($1.25B 評価額)',
  $md$## Goodfire とは

Goodfire は 2024 年設立のサンフランシスコ拠点 AI Interpretability (解釈可能性) スタートアップ。
**AI モデル内部のニューロンを直接読み解き、編集可能にする** プラットフォーム「Ember」を開発。

「AI のブラックボックスを開く」というミッションのもと、
GPT/Claude/Llama 等のフロンティアモデルの内部表現を可視化・操作する技術を提供している。

## 資金調達履歴 (2026-04 時点)

| ラウンド | 金額 | 評価額 | 主要投資家 | 時期 |
|---------|------|-------|-----------|------|
| Seed | $7M | — | Lightspeed | 2024-08 |
| Series A | **$50M** | — | Menlo Ventures + **Anthropic** | 2025-04 |
| Series B | **$150M** | **$1.25B** | B Capital | 2026-02 |
| **累計** | **$207M** | **🦄 ユニコーン** | | |

**注目点**: Series A に Anthropic が直接出資 — 安全な AI 研究との戦略的提携を示唆。

## 既存 129 社との差別化軸

| 観点 | Goodfire | 既存 LLM/動画/音声 プロバイダー |
|------|----------|-------------------------------|
| **カテゴリ** | Interpretability (解釈可能性) | 生成・推論 |
| **対象** | 既存モデルの「内部」を解読 | 新モデルを「外部から」呼び出し |
| **出力** | ニューロン活性化マップ・特徴量 | テキスト/画像/動画/音声 |
| **顧客** | AI 研究者・規制対応企業・ヘルスケア | 一般開発者・コンテンツ制作者 |
| **競合** | (ほぼ無し — Anthropic 内部研究のみ) | OpenAI/Google/Meta etc 大量 |

## 主要プロダクト

### Ember (2024-12 公開 → 2026-02 partner-only に転換)

- **AI モデルの内部ニューロンに直接アクセス**できる API/SDK
- Sparse Autoencoders (SAEs) で隠れ層を解釈可能な特徴に分解
- モデル挙動を「外部 prompt」ではなく「内部編集」で制御
- 2026-02 時点では select partners 向け提供 (一般 API は廃止)
- ただし **SAE 重みは OSS 公開** — 研究用途では誰でも再現可能

### 最新成果 (2026-02)

**Alzheimer's biomarker 発見**:
- Prima Mente 社のエピジェネティクス基盤モデルを Goodfire の手法で逆解析
- アルツハイマー病の新しいバイオマーカークラスを特定
- **基盤モデル逆解析による自然科学領域での重大発見の最初の例**

## ビジネスモデル

- **Enterprise Partnership**: フロンティアモデル提供企業との共同研究
- **Healthcare/Biotech**: 創薬・診断 AI の解釈可能性提供
- **Regulatory Compliance**: EU AI Act 等の透明性要件対応支援
- **OSS SAE 重み**: 学術研究向けに無償公開 (コミュニティ拡大)

## 創業・組織

- 設立: 2024 年 (サンフランシスコ)
- CEO: Eric Ho (元 Anthropic 関係者)
- 共同創業者: Tom McGrath (元 DeepMind interpretability 研究者)
- 強み: SAE × Mechanistic Interpretability × プロダクト化$md$,
  '2026-04-20'
),
(
  'goodfire',
  'models',
  'Goodfire 技術スタック (Ember / Sparse Autoencoders)',
  $md$## 技術アーキテクチャ

```text
┌─────────────────────────────────────────────────┐
│  対象モデル (GPT-4 / Claude / Llama 3 / 自社)    │
│  ↓ 隠れ層 activation を抽出                      │
├─────────────────────────────────────────────────┤
│  Sparse Autoencoder (SAE) — 重ね合わせ分離       │
│  ↓ 数百万次元の解釈可能特徴に分解                │
├─────────────────────────────────────────────────┤
│  Ember Platform                                  │
│  - 特徴の意味自動ラベル付け                       │
│  - 因果介入 (steering / ablation)                │
│  - 視覚化ダッシュボード                           │
└─────────────────────────────────────────────────┘
```

## Sparse Autoencoder (SAE) とは

LLM の隠れ層は数千次元のベクトルだが、これは**多数の「概念」が重ね合わせ**で
詰め込まれた状態 (superposition)。SAE はこの重ね合わせを分離し、
各次元が単一概念に対応するよう変換する技術。

```python
# 概念例 (Goodfire OSS SAE で観測される特徴の一部)
features = {
    "12345": "金融用語 (株価・利回り・債券)",
    "67890": "プログラミング (Python関数定義)",
    "11111": "Golden Gate Bridge 関連知識",
    "22222": "礼儀正しい応答スタイル",
    "33333": "数値推論ステップ",
}
```

各特徴を **強制的にON/OFF** することで、モデル挙動を編集可能。

## 公開モデル/データセット

| 名称 | 内容 | ライセンス |
|------|------|-----------|
| **goodfire/Llama-3.1-8B-Instruct-SAE** | Llama 3.1 8B の全層 SAE 重み | Apache 2.0 |
| **goodfire/feature-labels** | 自動ラベル付き特徴データセット | CC-BY |
| **Sparse Crosscoders** | モデル間特徴対応マッピング | OSS (paper) |
| **Goodfire Workbench** | SAE 操作 Web UI (廃止予定) | — |

## 既存 AI 開発との統合パターン

| 用途 | 方法 |
|------|------|
| **モデル監査** | 危険な特徴 (差別・違法行為) が活性化していないか自動検出 |
| **ファインチューニング代替** | 高コスト fine-tune の代わりに特徴 steering で挙動調整 |
| **デバッグ** | 「なぜこの出力が出たか」を特徴活性化で逆追跡 |
| **A/B テスト** | 特徴を直接編集し挙動変化を比較 |

## 自分株式会社からの活用イメージ

| 機能 | Goodfire 適用 |
|------|--------------|
| **AI 大学** | 「LLM の中身はどう動いているか」体験コンテンツ (SAE 視覚化) |
| **AI 安全性教育** | 教材として superposition / mechanistic interp 概念説明 |
| **ai-hub 監視** | 既存 ai-hub のレスポンスから危険特徴を検出して遮断 |
| **コスト最適化** | 高コスト fine-tune の代わりに steering で出力制御 |

## 関連ベンチマーク・論文

- **Anthropic Sparse Autoencoders** (2024-05) — Goodfire の研究的祖先
- **OpenAI's "Scaling Monosemanticity"** (2024-09) — 同方向研究
- **Goodfire Llama 3 SAE Paper** (2024-12) — 8B モデル全層分解
- **Prima Mente × Goodfire Alzheimer's** (2026-02) — 自然科学への応用第一号$md$,
  '2026-04-20'
),
(
  'goodfire',
  'api',
  'Goodfire 使い方 (OSS SAE + Partner API)',
  $md$## 現状の利用方法 (2026-04 時点)

Goodfire の Ember API は 2026-02 から **select partner 専用** に転換。
ただし以下の経路で技術を試せる:

### 1. OSS SAE 重みを HuggingFace から利用 (推奨・無料)

```python
# pip install transformers torch
import torch
from transformers import AutoModel, AutoTokenizer

# Llama 3.1 8B の Goodfire SAE 重みを取得
sae_repo = "goodfire/Llama-3.1-8B-Instruct-SAE"
sae = AutoModel.from_pretrained(sae_repo, trust_remote_code=True)
tokenizer = AutoTokenizer.from_pretrained("meta-llama/Llama-3.1-8B-Instruct")

# 入力をトークナイズ → SAE で特徴分解
text = "The Golden Gate Bridge is in San Francisco."
inputs = tokenizer(text, return_tensors="pt")
with torch.no_grad():
    activations = sae.encode(inputs.input_ids)  # [batch, seq, n_features]

# トップ活性化特徴を取得
top_features = activations.topk(k=5, dim=-1)
print(f"Top 5 features per token: {top_features.indices}")
```

### 2. Anthropic 経由で間接利用

Series A 投資元の Anthropic は Claude 内部で類似 SAE 技術を使用。
Anthropic API で `system` prompt に明示的解釈要求を入れると
近似的な mechanistic interp が得られる:

```typescript
const response = await anthropic.messages.create({
  model: "claude-opus-4-7",
  max_tokens: 2000,
  system: "You are an interpretability researcher. For each output, "
        + "list the top 3 conceptual features that influenced your answer.",
  messages: [{ role: "user", content: "Why is the sky blue?" }]
});
// response includes step-by-step feature attribution
```

### 3. Goodfire Partner Program (Enterprise のみ)

```text
申込先: https://www.goodfire.ai/contact
対象: 1B+ パラメータ モデルを保有する企業・研究機関
要件: 用途明示 (規制対応 / 創薬 / 安全性研究 etc)
リードタイム: 2-4 週間 (個別審査)
価格: 非公開 (推定 $50K-500K/年)
```

## Flutter Web (自分株式会社) からの呼出例

直接 Goodfire を呼ぶのではなく、SAE 結果を Supabase EF にバッチ処理で保存し、
ai-hub から参照するパターン:

```dart
// lib/services/interpretability_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class InterpretabilityService {
  static Future<List<FeatureActivation>> explainResponse({
    required String responseText,
    required String model,
  }) async {
    final supabase = Supabase.instance.client;
    final response = await supabase.functions.invoke(
      'ai-hub',
      body: {
        'action': 'interpret.features',
        'text': responseText,
        'model': model,         // 'llama-3.1-8b' 等 (SAE 対応モデル)
        'top_k': 5,
      },
    );
    final data = (response.data as Map?)?['features'] as List? ?? [];
    return data.map((e) => FeatureActivation.fromJson(e)).toList();
  }
}
```

```typescript
// supabase/functions/ai-hub/actions/interpret.ts (new action)
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

export async function interpretFeatures(payload: {
  text: string; model: string; top_k: number;
}) {
  // Option A: 自社で OSS SAE をホスト (Modal/Replicate 経由)
  const inferenceUrl = Deno.env.get("SAE_INFERENCE_URL");
  const response = await fetch(`${inferenceUrl}/encode`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const { features } = await response.json();
  return new Response(JSON.stringify({ features }));
}
```

## 料金 (推定)

- **OSS SAE 重み**: 完全無料 (HuggingFace ダウンロード)
- **自前 SAE inference (GPU)**: $0.01-0.10 per 1K tokens (Replicate/Modal 推定)
- **Partner Ember API**: $50K-500K/年 (Enterprise 個別契約)

## 注意事項・制約

- **対応モデルは限定的**: 主に Llama 3.1 8B / 7B 系。GPT/Claude の SAE は非公開
- **特徴ラベル品質**: 自動ラベルは英語中心 — 日本語特徴のラベル精度は劣る
- **計算コスト**: SAE 推論は base model の 1.5-2 倍の VRAM 消費
- **倫理**: 「モデル編集」技術は jailbreak にも転用可 — 利用ポリシー要遵守

## 公式リソース

- Web: https://www.goodfire.ai/
- Blog: https://www.goodfire.ai/blog
- Ember 解説: https://www.goodfire.ai/blog/announcing-goodfire-ember
- Series B 発表: https://www.goodfire.ai/blog/series-b
- HuggingFace: https://huggingface.co/goodfire
- Research papers: https://www.goodfire.ai/research$md$,
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
