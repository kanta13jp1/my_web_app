-- World Labs (Fei-Fei Li) 初期コンテンツシード (2026-04-17)
INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order) VALUES

('world_labs', 'overview', 'World Labs 概要',
$$World Labs は「AI の母 (Godmother of AI)」として知られるスタンフォード大教授 **Fei-Fei Li** が共同創業したスタートアップ。「**Spatial Intelligence (空間知能)**」こそが次世代 AI のフロンティアと提唱し、**Large World Models (LWM)** — 物理法則と幾何学構造を理解する AI モデル — を開発している。

2026年1月には **World API** を公開し、開発者とロボティクス企業に LWM へのアクセスを提供開始。テキスト・1枚画像・複数画像・360°パノラマ・動画のマルチモーダル入力から、**航行可能な 3D 世界** (レイアウト・奥行き・照明・空間構造) を生成する。出力は **USD (Universal Scene Description)** などプロ向け標準 3D フォーマットに対応。

## 主要サービス
- **World API**: マルチモーダル→3D世界生成 API (2026年1月公開)
- **Large World Models (LWM)**: 物理法則理解の基盤モデル
- **USD エクスポート**: 映画・ゲーム業界標準 3D フォーマット
- **Embodied AI 開発支援**: ロボット訓練環境 (Sim-to-Real ギャップ解消)

## 強み
- **空間知能フロンティア**: 2D 画像生成を超えた 3D インタラクティブ世界
- **Fei-Fei Li 創業**: ImageNet 生みの親・スタンフォードAI研究所長
- **$1 billion 調達**: 2026年時点で世界最高額クラスの AI スタートアップ調達
- **プロ向けフォーマット**: 建築・ゲーム・映画業界で即活用可能
- **Embodied AI**: ロボット訓練用フォトリアリスティック環境生成$$,
'https://www.worldlabs.ai/', '2026-04-17', 1),

('world_labs', 'models', 'World Labs モデル一覧 (2026)',
$$## Large World Models (LWM)

| モデル | 入力 | 出力 | 用途 |
| :--- | :--- | :--- | :--- |
| **World LWM v1** | テキスト | 3D 世界 (USD) | プロンプトから世界生成 |
| **World LWM (Image)** | 1枚画像 | 3D 世界 | 既存画像を3D化 |
| **World LWM (Multi-view)** | 複数画像 | 精密 3D 世界 | 部屋・建築物スキャン |
| **World LWM (360°)** | 360°パノラマ | 完全 3D 環境 | VR・メタバース |
| **World LWM (Video)** | 動画 | 動的 3D シーン | 映画撮影データ→3D |

## 出力フォーマット

| フォーマット | 用途 |
| :--- | :--- |
| **USD (Universal Scene Description)** | Pixar発・映画/アニメ業界標準 |
| **glTF** | Web/ゲーム業界標準 |
| **点群 (Point Cloud)** | ロボット SLAM・LiDAR 統合 |
| **メッシュ (OBJ/FBX)** | 建築・CAD統合 |

## 特徴的な機能
- **物理法則理解**: 重力・衝突・光学を考慮した生成
- **Navigable Worlds**: 生成された世界を自由に移動可能
- **マルチモーダル入力**: テキスト・画像・動画・360°全対応
- **Embodied AI 訓練**: ロボット・自動運転のシミュレーション基盤
- **科学応用**: 物理シミュレーション・分子構造解析への拡張検討中$$,
'https://www.worldlabs.ai/blog', '2026-04-17', 2),

('world_labs', 'api', 'World API 入門',
$$## World API の始め方

```python
import requests

# テキスト→3D世界生成
url = "https://api.worldlabs.ai/v1/worlds/generate"
headers = {
    "Authorization": "Bearer YOUR_WORLD_LABS_API_KEY",
    "Content-Type": "application/json"
}
payload = {
    "input_type": "text",
    "prompt": "江戸時代の京都の街並み、春の桜が満開",
    "output_format": "usd",  # USD / glTF / point_cloud
    "quality": "high"
}

response = requests.post(url, headers=headers, json=payload)
task_id = response.json()["task_id"]

# 非同期ジョブのポーリング
status_url = f"https://api.worldlabs.ai/v1/worlds/tasks/{task_id}"
# status が "completed" になったら URL から USD ダウンロード
```

## 画像→3D 世界

```python
payload = {
    "input_type": "image",
    "image_url": "https://example.com/room.jpg",
    "output_format": "gltf",
    "include_lighting": True,
    "include_physics": True
}
```

## 料金 (2026年4月時点)
- **Free tier**: 月 10 世界生成 (低解像度)
- **Pro**: $99/月 — 500 世界生成
- **Enterprise**: カスタム (SLA / オンプレ配置オプション)
- **大規模スキャン (Multi-view/360°)**: 追加料金

## 主要エンドポイント
- `POST /v1/worlds/generate` — 新規 3D 世界生成
- `GET /v1/worlds/tasks/{id}` — ジョブステータス
- `POST /v1/worlds/{id}/edit` — 既存世界の編集
- `POST /v1/worlds/{id}/export` — 別フォーマットでエクスポート
- `POST /v1/worlds/simulate` — 物理シミュレーション実行

## 認証
World Labs Developer Console で API Key 発行。生成にかかる時間は世界の複雑度により 30秒〜数分 (非同期ジョブベース)。$$,
'https://www.worldlabs.ai/', '2026-04-17', 3)

ON CONFLICT DO NOTHING;
