-- Issues #5157 & #5150: AI21 Labs 概要・モデルコースのエビデンス契約・Maestro/Jamba/プライベートデプロイ選定基準・更新日付の強化
UPDATE ai_university_contents
SET
  description = $md$
# AI21 Labs 概要 — Maestro / Jamba / エンタープライズ導入基盤

**AI21 Labs** はイスラエル発のエンタープライズ特化型 AI 企業。
独自オーケストレーション基盤 **AI21 Maestro**、SSM+Transformer 融合アーキテクチャの **Jamba シリーズ** (256K 超長コンテキスト)、およびセキュアなプライベート・VPC デプロイ環境を提供します。

## 対象学習者 & 到達目標
- **対象者**: エンタープライズ AI 導入責任者、長文ドキュメント分析・RAG 基盤のコスト最適化を目指すエンジニア
- **到達目標**: Maestro (オーケストレーション) / Jamba (LLM) / プライベート VPC 導入 の各適用要件を理解し、企業のガバナンス・レイテンシ・予算に応じた最適な構成選定メモを作成できる

## AI21 エコシステム構成マップ (2026)

| コンポーネント | 役割 | 主な特徴 | 推奨ワークロード |
| :--- | :--- | :--- | :--- |
| **AI21 Maestro** | エージェント・オーケストレーション | モデル非依存ルーティング・予算ガードレール・追跡可能性 | 複数 LLM 連携・複雑な業務ワークフロー |
| **Jamba 1.5 Large** | 超長文推論・高品質 LLM | 256K コンテキスト・MoE 構造 (アクティブ 94B / 総 398B) | 法務契約書・財務諸表の精密横断分析 |
| **Jamba 1.5 Mini** | 高速・高コスト効率 LLM | 256K コンテキスト・MoE 構造 (アクティブ 12B / 総 52B) | 高スループット RAG・要約バッチ処理 |
| **Private / VPC** | 専用環境デプロイ | AWS Bedrock / Azure / オンプレミス完全閉域網 | 機密顧客データ・厳格な金融/医療コンプライアンス |

## 意思決定ガイドライン (30分設計ラボ)
1. **機密・閉域網必須**: AWS Bedrock または Azure 経由の Jamba プライベートインスタンスを選択
2. **モデル混在・予算上限管理**: Maestro によるタスク別動的ルーティングとコスト制限ガードレールを適用
3. **長文コンテキスト・低レイテンシ**: Jamba 1.5 Mini を第一候補として検証
$md$,
  source_url = 'https://www.ai21.com/',
  published_at = '2026-09-02'
WHERE provider_id = 'ai21' AND (title LIKE '%AI21 Labs 概要%' OR id = '9138a4ef-d8e8-4308-aa4f-4b93aac6ff39' OR sort_order = 1);

UPDATE ai_university_contents
SET
  description = $md$
# AI21 Labs — 利用可能モデル & Jamba アーキテクチャ (2026)

Jamba (Joint Attention and Mamba) は、**SSM (State Space Model) の推論速度・メモリ効率** と **Transformer の注意機構・文脈理解力** を融合したハイブリッド MoE (Mixture-of-Experts) モデルです。

## 主力モデル仕様 & ベンチマーク (2026)

| モデル名 | コンテキスト長 | 総パラメータ / 有効パラメータ | 推奨ユースケース | トークン単価 (入力 / 出力 1M) |
| :--- | :--- | :--- | :--- | :--- |
| **Jamba 1.5 Large** | **256K** (約800頁) | 398B / 94B (MoE) | 高度な推論・多言語法務分析・複雑な構造化抽出 | $2.00 / $8.00 |
| **Jamba 1.5 Mini** | **256K** (約800頁) | 52B / 12B (MoE) | 大規模 RAG・長文要約・リアルタイムチャット | $0.20 / $0.40 |

## Jamba の構造的アドバンテージ
- **8倍の推論スループット**: 従来の標準 Transformer と比較し、長文処理時の KV キャッシュ消費を最大 80% 削減
- **ネイティブ 256K 対応**: Needle-in-a-Haystack テストで 100% の情報回収率を実証
- **OpenAI 互換エンドポイント**: `https://api.ai21.com/studio/v1` で既存コードを最小改修で移行可能
$md$,
  source_url = 'https://docs.ai21.com/docs/jamba-models',
  published_at = '2026-09-02'
WHERE provider_id = 'ai21' AND (title LIKE '%利用可能モデル%' OR sort_order = 2);
