-- PS版#3 Session 6: Weights & Biases (wandb) — ML 実験管理・MLOps プラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'wandb',
  'overview',
  'Weights & Biases — ML 実験管理・モデル監視・LLMOps の業界標準',
  E'## Weights & Biases (W&B) とは\n\nWeights & Biases は 2017 年設立のサンフランシスコ発 MLOps プラットフォーム。\n機械学習の実験管理から LLM の評価・本番監視まで、**ML ライフサイクル全体を管理**するツールを提供。\n\nOpenAI・Anthropic・NVIDIA・Toyota などが利用し、200 万人以上の ML エンジニアに支持される業界標準ツール。\n累計調達 $200M 以上、評価額 $1.25B のユニコーン。\n\n## 主な製品\n\n- **W&B Runs**: 実験のハイパーパラメータ・メトリクスを自動追跡\n- **W&B Sweeps**: ハイパーパラメータ自動最適化\n- **W&B Artifacts**: モデル・データセットのバージョン管理\n- **W&B Reports**: 実験結果の可視化・共有\n- **W&B Weave**: LLM アプリケーションのトレーシング・評価\n\n## 活用事例\n\n- **モデル訓練管理**: 損失・精度・GPU 使用率をリアルタイム可視化\n- **LLM 評価**: プロンプト・モデル比較を系統的に記録\n- **チーム共有**: 実験結果をダッシュボードで共有・議論\n- **本番監視**: デプロイ後のモデル性能ドリフト検出',
  '2026-04-20'
),
(
  'wandb',
  'models',
  'W&B 製品・機能一覧',
  E'## W&B Runs（実験追跡）\n\n- `wandb.init()` で実験開始 → ハイパーパラメータを自動記録\n- `wandb.log()` でメトリクスをリアルタイム送信\n- 複数実験を比較・フィルタリング\n- GPU / CPU / メモリ使用率を自動モニタリング\n\n## W&B Sweeps（自動チューニング）\n\n```yaml\nmethod: bayes  # random / grid / bayes\nmetric:\n  name: val_accuracy\n  goal: maximize\nparameters:\n  learning_rate:\n    min: 0.0001\n    max: 0.1\n  batch_size:\n    values: [16, 32, 64, 128]\n```\n\n- ベイズ最適化 / ランダム / グリッドサーチ対応\n- 分散実行対応\n\n## W&B Weave（LLMOps）\n\n- LLM 呼び出しのトレーシング\n- プロンプトバリエーション A/B テスト\n- 人間評価 + LLM-as-a-judge による品質スコア\n- 本番の LLM コスト・遅延モニタリング\n\n## W&B Artifacts\n\n- モデルチェックポイントのバージョン管理\n- データセットのリネージ追跡\n- モデルレジストリ（本番デプロイ管理）\n\n## 料金\n\n| プラン | 月額 | ストレージ |\n|--------|------|------------|\n| Free | $0 | 個人利用 |\n| Team | $50/ユーザー | チーム共有 |\n| Enterprise | 要相談 | オンプレ + SAML |',
  '2026-04-20'
),
(
  'wandb',
  'api',
  'W&B API 使い方',
  E'## インストール\n\n```bash\npip install wandb\nwandb login  # ブラウザで API キー取得\n```\n\n## 基本的な実験追跡\n\n```python\nimport wandb\n\n# 実験開始\nrun = wandb.init(\n    project="ai-university-model",\n    config={\n        "learning_rate": 0.001,\n        "batch_size": 32,\n        "epochs": 100,\n        "model": "transformer"\n    }\n)\n\n# 訓練ループ内でメトリクス記録\nfor epoch in range(100):\n    train_loss, val_accuracy = train_epoch(...)\n    wandb.log({\n        "epoch": epoch,\n        "train/loss": train_loss,\n        "val/accuracy": val_accuracy\n    })\n\n# モデル保存\nwandb.save("model.pth")\nrun.finish()\n```\n\n## LLM アプリのトレーシング (Weave)\n\n```python\nimport weave\nfrom anthropic import Anthropic\n\nweave.init("my-llm-app")\nclient = Anthropic()\n\n@weave.op()\ndef generate_response(prompt: str) -> str:\n    response = client.messages.create(\n        model="claude-sonnet-4-6",\n        max_tokens=1024,\n        messages=[{"role": "user", "content": prompt}]\n    )\n    return response.content[0].text\n\n# 自動でトレース・コスト・遅延を記録\nresult = generate_response("AI大学の最新プロバイダーは？")\n```\n\n## ハイパーパラメータ最適化\n\n```python\nimport wandb\n\ndef train(config=None):\n    with wandb.init(config=config):\n        config = wandb.config\n        model = build_model(config.layers, config.hidden_size)\n        # ...\n        wandb.log({"val_loss": val_loss})\n\nsweep_config = {\n    "method": "bayes",\n    "metric": {"name": "val_loss", "goal": "minimize"},\n    "parameters": {\n        "layers": {"values": [2, 4, 8]},\n        "hidden_size": {"min": 64, "max": 512}\n    }\n}\nsweep_id = wandb.sweep(sweep_config, project="my-project")\nwandb.agent(sweep_id, train, count=20)\n```\n\n## 活用シーン\n\n- **EF の AI モデル改善**: Claude/Gemini プロンプト A/B テストを Weave で記録\n- **競馬予測モデル管理**: 精度・特徴量の変化を Runs で追跡\n- **コスト監視**: LLM API コスト・トークン使用量をリアルタイム可視化',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
