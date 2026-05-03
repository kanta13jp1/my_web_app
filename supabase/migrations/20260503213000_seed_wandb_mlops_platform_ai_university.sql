-- PS#3 S149: AI大学 Weights & Biases MLOps総合ガイド追加 (Issue #1802)
-- Source: 7ccb0520 Weights & Biases: Comprehensive AI Developer Platform Guide

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'wandb', 'mlops_comprehensive_2026',
  'Weights & Biases 総合MLOpsガイド 2026 — Weave LLMOps・モデルレジストリ・W&B Runs高度活用 (10/10)',
  $$## W&B 2026 総合ガイド

**Weights & Biases** は2026年時点で**LLMOps（大規模言語モデル運用）**の中核プラットフォームとして進化。実験管理から**LLMのトレース・評価・デプロイ**まで一気通貫でカバーする「AI開発のオブザーバビリティ基盤」。

## W&B Weave — LLMOps 専用機能

```
[Weave Traces]
  ・LLMアプリのすべてのコールを自動記録
  ・プロンプト→LLM API→レスポンスの完全トレース
  ・レイテンシ・トークン数・コストを自動集計
  ・エラー発生箇所をビジュアルで特定

[Weave Evaluations]
  ・カスタム評価指標でLLMの品質を継続測定
  ・人間評価 vs AI評価 のハイブリッド評価
  ・A/Bテスト: プロンプト・モデル・パラメータの比較
  ・回帰テスト: 新バージョンで品質が下がっていないか確認

[Dataset & Versioning]
  ・学習データ・評価データのバージョン管理
  ・データのリネージ（どこから来たデータか）追跡
  ・Git LFSと統合した大容量データ管理
  ・チームでのデータ共有・再現性確保
```

## W&B Model Registry

| 機能 | 詳細 |
|------|------|
| モデル登録 | 実験から直接モデルをレジストリへ昇格 |
| ステージ管理 | Staging → Production → Archived |
| アーティファクト | モデル重み・設定・依存関係を一式管理 |
| CI/CD統合 | GitHub ActionsでモデルデプロイをトリガーしW&Bで追跡 |
| アクセス制御 | チーム・プロジェクト単位でモデルへのアクセス制限 |

## W&B Runs 高度活用パターン

```python
import wandb

# 基本的な実験追跡
run = wandb.init(
    project="my-llm-project",
    config={"model": "claude-sonnet-4-6", "temperature": 0.7}
)

# LLMコストとトークン追跡
wandb.log({
    "prompt_tokens": 1500,
    "completion_tokens": 800,
    "cost_usd": 0.023,
    "latency_ms": 1200,
    "quality_score": 0.87
})

# Sweeps: ハイパーパラメータ自動探索
sweep_config = {
    "method": "bayes",
    "parameters": {
        "temperature": {"min": 0.1, "max": 1.0},
        "max_tokens": {"values": [256, 512, 1024]}
    }
}
```

## 自分株式会社 AI 大学での位置づけ

- **カテゴリ**: データ基盤 / MLOps / LLMOps学科
- **関連プロバイダー**: MLflow / DVC / Hugging Face / Supabase
- **実用的示唆**: W&B WeavesをClaude APIに使うと全LLMコールのコスト・品質を可視化
  → 自分株式会社のquota監視・コスト削減KPIに直結
$$,
  'https://docs.wandb.ai/',
  '2026-01-01',
  96
)
ON CONFLICT (provider, category) DO NOTHING;
