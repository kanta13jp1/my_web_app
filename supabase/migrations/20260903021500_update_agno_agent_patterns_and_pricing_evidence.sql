-- Issue #5142: Agno エージェント設計パターン & 料金コースのエビデンス契約・Agent/Team/Workflow選定・料金TCO更新
UPDATE ai_university_contents
SET
  description = $md$
# Agno エージェント設計パターン & プラットフォーム料金体系 (2026)

**Agno (旧 phidata)** は、Python-native な超高速マルチエージェント基盤です。
単一の `Agent`、複数エージェントが協調する `Team`、そして決定論的制御を行う `Workflow` の 3 つの設計パターンを提供します。

## 対象学習者 & 到達目標
- **対象者**: 自社業務にマルチエージェントを導入検討している AI エンジニアおよびテクニカルプロダクトマネージャー
- **到達目標**: 業務要件に応じて `Agent` / `Team` (coordinate/route/broadcast) / `Workflow` を適切に選定し、Agno Platform + LLM トークン + インフラの月額 TCO を算定できる

## 3 つの設計パターン比較 (2026)

| パターン | 制御方式 | 主な特徴 | 推奨ユースケース |
| :--- | :--- | :--- | :--- |
| **Agent (単一)** | 自律 Tool Calling | Memory (SQLite/Postgres) と VectorDB を内蔵した単一エージェント | 単一ドメインの QA・要約・データ抽出 |
| **Team (協調)** | 動的オーケストレーション | `coordinate`, `route`, `broadcast`, `tasks` によるエージェント間協調 | 調査・執筆・レビューの多段階パイプライン |
| **Workflow (固定)** | 決定論的 DAG 制御 | Python コードによる厳格なステップ制御 (条件分岐・並行処理) | 金融取引・厳格な審査・監査トレース必須業務 |

## Agno Platform 料金体系 (2026) & 月額 TCO 計算

| プラン | 月額料金 | 含まれるリソース | 追加オプション |
| :--- | :--- | :--- | :--- |
| **Free (OSS)** | **$0** | ローカル実行無制限・コミュニティサポート | - |
| **Pro** | **$150 / 月** | 3 シート・1 ライブ接続・監視/セッション管理 UI | 追加シート +$30/月, 追加接続 +$95/月 |
| **Enterprise** | カスタム | 無制限シート・SLA・専用 VPC / オンプレミス展開 | 要問い合わせ |

### 月額 TCO (Total Cost of Ownership) 試算例 (Pro 導入・月間 10 万リクエスト)
- **Agno Pro プラットフォーム**: $150
- **LLM トークン費用 (Claude Sonnet / Haiku 混在)**: 約 $450
- **PostgreSQL / pgvector (Supabase Pro)**: $25
- **月額合計 TCO**: **約 $625 / 月**

## 実践 60 分ラボ: Team モード構築 & TCO 算定メモ
1. `pip install "agno>=1.0.0"` で環境をセットアップ
2. `Team(mode="coordinate", agents=[researcher, writer])` を実装
3. 実行ログ・トークン消費量を計測し、月間運用 TCO メモを提出
$md$,
  source_url = 'https://docs.agno.com/',
  published_at = '2026-09-02'
WHERE provider_id = 'agno' AND (title LIKE '%エージェント設計パターン%' OR id = '6dba658f-c89c-4a8e-86c6-750c26d51fa2' OR sort_order = 2);
