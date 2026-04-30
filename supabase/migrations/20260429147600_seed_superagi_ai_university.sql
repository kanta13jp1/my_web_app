-- PS#3 S136: AI大学 367→368社化 — SuperAGI (OSS自律エージェントインフラ / プロダクション対応 / GUI + マルチエージェント)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'superagi', 'overview',
  'SuperAGI — OSS自律エージェントインフラ・プロダクション対応GUI・マルチエージェント管理 (9/9)',
  $$## SuperAGI とは

**SuperAGI** は 2023年5月に公開された、**BabyAGI / AutoGPT を本番環境で使えるレベルに昇華した**オープンソースの自律 AI エージェントフレームワーク。

「エージェントをプロダクションで動かす」ことに特化した設計で、**GUI での管理画面 / 複数エージェントの並列実行 / パフォーマンス監視** などのエンタープライズ機能を初期から備えていた。

## SuperAGI の設計哲学

```
BabyAGI / AutoGPT の課題 → SuperAGI の解決:

  課題1: 終了条件なし・暴走
    BabyAGI: 無限ループで止まらない
    SuperAGI: Goals + Constraints 設定 / 人間承認フロー

  課題2: CLI のみで管理困難
    AutoGPT: ターミナルのみ
    SuperAGI: Web GUI でエージェント状態をリアルタイム監視

  課題3: 1エージェントのみ
    BabyAGI: 単一エージェント
    SuperAGI: 複数エージェントを並列実行・協調

  課題4: コスト無制限
    AutoGPT: API コスト青天井
    SuperAGI: Token 上限・コスト追跡機能

  課題5: 永続化なし
    BabyAGI: 再起動で状態消失
    SuperAGI: PostgreSQL で永続化・再開可能
```

## SuperAGI のアーキテクチャ

```
SuperAGI のコンポーネント:

  Agent (エージェント):
    ・Goals: 達成すべき目標リスト
    ・Instructions: 行動指針
    ・Tools: 使用可能ツール
    ・Model: GPT-4 / Claude / Gemini など
    ・Max Iterations: 最大実行回数 (暴走防止)

  Toolkit (ツールキット):
    ・ファイル読み書き
    ・Web ブラウジング
    ・GitHub 操作
    ・Slack / Email 送信
    ・コード実行 (Docker サンドボックス)
    ・カスタムツール追加可

  Agent Manager (管理):
    ・複数エージェントのスケジューリング
    ・並列実行制御
    ・リソース配分

  Dashboard (GUI):
    ・実行ログのリアルタイム表示
    ・エージェント状態の可視化
    ・パフォーマンスメトリクス

  Memory (記憶):
    ・Pinecone / Weaviate / Redis 対応
    ・長期記憶の永続化
    ・ベクトル検索
```

## 実際の使用例

```python
# SuperAGI Python SDK での使用
from superagi import SuperAGI

# エージェントを設定
agent = SuperAGI.create_agent(
    name="コードレビューエージェント",
    description="GitHubのPRをレビューしてIssueを作成する",
    goals=[
        "PRの変更をレビューする",
        "問題点を特定する",
        "GitHub Issueとしてレポートを作成する"
    ],
    instructions=[
        "コードの品質・セキュリティ・パフォーマンスをチェック",
        "日本語でコメントを書く",
        "重大な問題は HIGH priority でマークする"
    ],
    tools=["github", "web_browser"],
    model="gpt-4",
    max_iterations=20  # 最大20回で強制終了
)

# 実行 (非同期)
run = agent.run()
print(f"Agent run started: {run.id}")

# 状態確認
status = run.get_status()
print(f"Status: {status.state}")  # RUNNING / COMPLETED / FAILED
print(f"Iterations: {status.iterations}")
print(f"Tokens used: {status.tokens_used}")
```

## SuperAGI と Docker

```
SuperAGI のセルフホスト構成 (docker-compose):

  services:
    superagi:
      image: superagi/superagi
      ports: ["3000:3000"]
      environment:
        - OPENAI_API_KEY=...
        - DATABASE_URL=postgresql://...
        - REDIS_URL=redis://...

    postgres:
      image: postgres:15
      volumes: ["./data:/var/lib/postgresql/data"]

    redis:
      image: redis:7
      volumes: ["./redis-data:/data"]

  → docker-compose up で即起動
  → ブラウザで localhost:3000 にアクセス
  → GUI でエージェントを設定・実行
```

## SuperAGI のエコシステム

```
SuperAGI のコミュニティ / 周辺ツール:

  Marketplace:
    ・コミュニティ製 Toolkit の配布サイト
    ・インストール1クリック
    ・Notion / Jira / HubSpot など

  SuperCoder:
    ・SuperAGI の派生
    ・コーディングに特化
    ・GitHub Actions 統合

  Agent Benchmark:
    ・エージェントの性能評価ツール
    ・タスク達成率・効率を計測
    ・モデル比較に活用

  Founder:
    ・Ishantt Sur (CEO)
    ・TransformerOptimus として OSS 公開
    ・Y Combinator 2023 Winter バッチ
```

## BabyAGI → AutoGPT → SuperAGI の進化

```
2023年 エージェント進化の系譜:

  BabyAGI (2023-04-02):
    ・タスクループの概念を定義
    ・140行、MIT
    ・プロトタイプ

  AutoGPT (2023-03-30):
    ・同時期に独立して登場
    ・ファイル保存・コード実行
    ・CLI ベース

  SuperAGI (2023-05-26):
    ・上記2つをプロダクション化
    ・GUI + 並列実行 + 永続化
    ・OSS + クラウドサービス

  Devin (2024-03):
    ・コーディング専門エージェント
    ・クローズドソース
    ・商用 SaaS ($500/月)

  Claude Code / Cursor (2024-2025):
    ・IDE 統合・実用化
    ・一般エンジニアが日常使い
    ・現在の標準
```

## 自分株式会社との関連

SuperAGI の「プロダクションでエージェントを管理する」設計は、自分株式会社の 12 インスタンス fleet 運用と同じ課題を先行解決している。特に「複数エージェントの並列実行 / 実行状態の GUI 監視 / コスト追跡 / PostgreSQL 永続化」は、現在 Win版が設計中の FLEET_SCALING_ROADMAP で必要な機能と一致する。SuperAGI の Toolkit アーキテクチャ (yaml定義 + Python実装) は ai-hub EF の action 設計の参考になる。また SuperAGI の Docker compose 構成は、自分株式会社の Supabase + EF + GHA の構成に置き換えられる。
$$,
  'https://github.com/TransformerOptimus/SuperAGI',
  NOW(),
  368
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  updated_at = NOW();
