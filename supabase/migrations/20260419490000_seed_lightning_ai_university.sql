-- PS版#3 Session 9: Lightning AI — PyTorch Lightning + クラウド GPU プラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'lightning_ai',
  'overview',
  'Lightning AI — PyTorch Lightning 開発チームが作るクラウド AI 開発環境',
  E'## Lightning AI とは\n\nLightning AI は PyTorch Lightning フレームワークの開発チームが 2022 年に設立した\n**クラウド AI 開発プラットフォーム**。\n「ローカル環境とクラウドの違いをなくす」をビジョンに、\nVS Code 同等の開発体験でクラウド GPU をシームレスに利用できる。\n\n累計調達 $58M+。PyTorch Lightning は GitHub スター 28,000+。\n\n## PyTorch Lightning との関係\n\n```text\nPyTorch (低レベル) → PyTorch Lightning (高レベル) → Lightning AI (クラウド)\n```\n\n- **PyTorch Lightning**: GPU/TPU/マルチノード学習のボイラープレートを排除\n- **Lightning AI**: Lightning を使った開発をクラウドで即実行\n\n## 主な特徴\n\n- **Lightning Studios**: クラウド VS Code 環境 + GPU を 1 クリック起動\n- **即時 GPU アクセス**: T4 〜 H100 を数秒で起動・停止\n- **実験管理**: 学習ログ・チェックポイント自動保存\n- **マルチノード学習**: DDP (分散データ並列) を設定なしで実行\n- **Lightning Fabric**: 研究コードを最小変更でスケールアップ\n\n## 活用事例\n\n- **LLM ファインチューニング**: Llama / Mistral をクラウド GPU でファインチューン\n- **CV モデル学習**: ResNet / ViT を分散学習で高速化\n- **強化学習**: GPU クラスタで並列環境を大量展開\n- **データサイエンス教育**: GPU 環境のセットアップ不要で即学習開始',
  '2026-04-20'
),
(
  'lightning_ai',
  'models',
  'Lightning AI 機能・Studio 一覧',
  E'## Lightning Studios\n\n### 環境タイプ\n\n| タイプ | 特徴 | 用途 |\n|--------|------|------|\n| **CPU Studio** | 無料・常時起動 | コード編集・軽量実行 |\n| **GPU Studio** | T4/A10G/A100/H100 | 学習・推論 |\n| **Collaboration** | チーム共有 | ペアプログラミング |\n\n### 主な機能\n\n#### Lightning Fabric (研究向け)\n```python\nimport lightning as L\n\nfabric = L.Fabric(accelerator="cuda", devices=4, strategy="ddp")\nfabric.launch()\nmodel, optimizer = fabric.setup(model, optimizer)\n\n# 通常の PyTorch ループがそのまま動く\nfor batch in dataloader:\n    loss = model(batch)\n    fabric.backward(loss)\n    optimizer.step()\n```\n\n#### PyTorch Lightning (全自動)\n```python\nclass LitModel(L.LightningModule):\n    def training_step(self, batch, batch_idx):\n        loss = self.model(batch)\n        self.log("train_loss", loss)  # 自動ログ\n        return loss\n\ntrainer = L.Trainer(\n    max_epochs=10,\n    accelerator="gpu",\n    devices=4,\n    strategy="ddp",\n    precision="16-mixed"  # 自動混合精度\n)\ntrainer.fit(model, dataloader)\n```\n\n### LLM ファインチューニング\n\n```python\nfrom lightning.pytorch import Trainer\nfrom lit_llama import LLaMA  # Lightning LLaMA 実装\n\ntrainer = Trainer(devices=4, strategy="deepspeed_stage_3")\ntrainer.fit(model)  # ZeRO-3 分散学習\n```\n\n## 料金\n\n| プラン | 月額 | 内容 |\n|--------|------|------|\n| Free | $0 | CPU Studio 無料・GPU 10時間/月 |\n| Pro | $39 | GPU 100時間/月 |\n| Teams | $79/人 | 無制限 GPU・チーム機能 |',
  '2026-04-20'
),
(
  'lightning_ai',
  'api',
  'Lightning AI 使い方',
  E'## インストール\n\n```bash\npip install lightning\n# Lightning AI Studio はブラウザで利用 (インストール不要)\n```\n\n## シンプルな分類モデル (PyTorch Lightning)\n\n```python\nimport lightning as L\nimport torch\nimport torch.nn as nn\nfrom torch.utils.data import DataLoader, TensorDataset\n\nclass SimpleClassifier(L.LightningModule):\n    def __init__(self):\n        super().__init__()\n        self.model = nn.Sequential(\n            nn.Linear(784, 256),\n            nn.ReLU(),\n            nn.Linear(256, 10)\n        )\n        self.criterion = nn.CrossEntropyLoss()\n\n    def training_step(self, batch, batch_idx):\n        x, y = batch\n        loss = self.criterion(self.model(x), y)\n        self.log("train_loss", loss, prog_bar=True)\n        return loss\n\n    def configure_optimizers(self):\n        return torch.optim.Adam(self.parameters(), lr=1e-3)\n\n# GPU/CPU を自動選択\ntrainer = L.Trainer(\n    max_epochs=10,\n    accelerator="auto",  # GPU があれば自動使用\n    devices="auto"\n)\ntrainer.fit(model, DataLoader(dataset))\n```\n\n## LLM ファインチューニング (Lit-GPT)\n\n```bash\n# Lightning が公開している LLM 学習スクリプト\ngit clone https://github.com/Lightning-AI/litgpt\ncd litgpt\npip install -e .\n\n# Mistral 7B のローカルファインチューニング\npython finetune/lora.py \\\n    --checkpoint_dir "checkpoints/mistralai/Mistral-7B-v0.1" \\\n    --data_dir "data/my_dataset"\n```\n\n## Lightning Fabric で既存コードを分散化\n\n```python\nimport lightning as L\n\n# 1. Fabric 初期化\nfabric = L.Fabric(accelerator="cuda", devices=8, strategy="ddp")\nfabric.launch()\n\n# 2. model/optimizer を setup (2行追加だけ)\nmodel = MyModel()\noptimizer = torch.optim.Adam(model.parameters())\nmodel, optimizer = fabric.setup(model, optimizer)  # ← この1行\ndataloader = fabric.setup_dataloaders(dataloader)  # ← この1行\n\n# 3. 既存の PyTorch ループそのまま (変更なし)\nfor batch in dataloader:\n    output = model(batch)\n    loss = criterion(output, batch["label"])\n    fabric.backward(loss)  # loss.backward() を置き換えるだけ\n    optimizer.step()\n    optimizer.zero_grad()\n```\n\n## 活用シーン\n\n- **AI 大学 実習**: PyTorch Lightning でモデル学習の定型化を学ぶ\n- **競馬予測モデル**: PyTorch Lightning で Horse Racing Ensemble を学習\n- **Modal との比較**: Modal はデプロイ特化 / Lightning AI は学習+実験管理特化',
  '2026-04-20'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
