-- Mira Network 初期コンテンツシード (2026-04-19)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('mira_network', 'overview', 'Mira Network 概要',
$$**Mira Network** は AI 出力を **暗号学的に検証可能 (cryptographically verifiable)** にする decentralized blockchain protocol。AI の幻覚 (hallucination) 問題を「複数ノードによる分散検証」で解決する trust layer。

500K+ ユーザー / 200K daily inferences を抱え、testnet で **Generate / Verify / Verified Generate** API スイートを公開。

主要モデル (mira/llama3.1 / GPT-4o / Llama 3.1 405B) を分散検証付きで呼び出せる。

## 主要サービス
- **Generate** API: 通常の AI inference
- **Verify** API: 既存出力を分散検証
- **Verified Generate** API: 生成 + 検証を一括実行
- Mira SDK (Python): credit 追跡 + workflow 管理
- $MIRA トークン経済 (staking + 検証 fee + governance)

## 強み
- **AI 出力の信頼性** を暗号学的に保証 (block chain 検証)
- 分散ノードネットワーク (単一障害点なし)
- 主要 LLM (GPT-4o / Llama 405B) に検証 layer を被せて使える
- ガバナンス + ステーキング token model$$,
'https://docs.mira.network/documentation/get-started/introduction', '2026-04-19', 1),

('mira_network', 'models', 'Mira Network モデル一覧 (2026)',
$$## 検証付き利用可能モデル

| モデル | プロバイダー | 特徴 |
| :--- | :--- | :--- |
| **mira/llama3.1** | Mira Network ネイティブ | 検証最適化 Llama |
| **GPT-4o** | OpenAI (検証付き) | フラッグシップ + 検証 |
| **Llama 3.1 405B** | Meta (検証付き) | OSS 最大級 + 検証 |

## 特徴的な機能
- **Verified Generate**: 1 コール で生成 + 検証 (= 結果の正確性スコア付き)
- **Verify only**: 任意の AI 出力を後付けで検証
- 分散ノードによる majority consensus
- 500K+ ユーザー / 200K daily inferences の規模

## ユースケース
- 医療・金融・法律など hallucination が許されない領域
- AI 出力の audit trail 確保
- 複数 LLM の出力を相互検証$$,
'https://docs.mira.network/', '2026-04-19', 2),

('mira_network', 'api', 'Mira Network API 入門',
$$## Mira Network API の始め方

```python
from mira_sdk import MiraClient

client = MiraClient(api_key="mira-...", credit_account="...")

# Verified Generate: 生成 + 分散検証 を 1 コール
result = client.verified_generate(
    model="mira/llama3.1",
    prompt="光合成のプロセスを説明してください",
)
print(result.text)
print(result.verification_score)  # 検証スコア (0.0-1.0)

# Verify only: 既存出力の検証
verification = client.verify(
    text="生成済みテキスト",
    context="背景コンテキスト",
)
```

## 料金 (2026年4月時点)
- 利用には **$MIRA トークン** が必要 (crypto)
- API/検証 fee は $MIRA で支払い
- ノード運営者は staking で報酬獲得
- 詳細料金: https://docs.mira.network/ 参照

## 自分株式会社での位置づけ
- **未実装** — crypto token 必須のため通常 Supabase Secrets では運用困難
- 将来 web3 wallet 統合機能を作る際の検証 layer 候補$$,
'https://docs.mira.network/documentation/get-started/introduction', '2026-04-19', 3)

ON CONFLICT DO NOTHING;
