-- Win版#132 part 24: AI大学 215→216社化 — Meshy 追加
-- Meshy: AI 3D モデル生成 / text-to-3D / image-to-3D / OBJ/FBX/GLB/USDZ / Game Dev / VR/AR

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'meshy',
  'overview',
  'Meshy — AI 3D モデル生成 (text-to-3D / image-to-3D / Game Dev・VR/AR 向け)',
  $$## Meshy — AI 3D モデル生成

**カテゴリ**: AI 3D Generation / Game Dev Tools / XR Asset Pipeline
**設立**: 2023年 / 本社: San Francisco, CA / シードラウンド完了
**特徴**: テキスト・画像から数分で高品質 3D メッシュ生成 / 業界標準フォーマット出力
**ユーザー**: ゲーム開発者 / 3D アーティスト / VR/AR 制作者 / プロダクトデザイナー
**評価**: 8/9

### 概要
Meshy は **text-to-3D / image-to-3D 生成 AI** の代表的サービス。テキストプロンプトまたは画像 1 枚から、約 1〜2 分で 3D メッシュ + テクスチャ + PBR マテリアルを生成できる。出力は OBJ / FBX / GLB / USDZ / STL の業界標準フォーマットで、Unity・Unreal・Blender・Three.js・WebXR にそのまま import 可能。NeRF 系の point cloud 出力ではなく、**ゲームエンジンで直接使える polygon mesh** を出力するのが最大の差別化点。Meshy-4 / Meshy-5 シリーズで品質が飛躍的に向上。

### 主な特長
- **Text-to-3D**: プロンプトから 3D モデル生成 (例: "wooden treasure chest with gold trim")
- **Image-to-3D**: 1 枚の画像 (正面 or 任意角度) から 3D 化
- **Text-to-Texture**: 既存メッシュに AI でテクスチャを再生成
- **AI Texture Painter**: テクスチャ部分のみリペイント
- **PBR マテリアル**: Albedo / Normal / Roughness / Metallic マップ出力
- **Quad / Triangle Mesh**: 用途に応じてトポロジー選択
- **Rigging (Beta)**: 自動ボーン推定 + スキニング (キャラクターモデル)
- **Style Variation**: Realistic / Cartoon / Voxel / Low-poly / Sculpture
- **Poly Count 制御**: 軽量モバイル向け 〜 ハイポリ映像向けまで指定可
- **API + Discord Bot + Web UI**: 開発フローに組込み可

### 出力フォーマット
| フォーマット | 用途 | 対応エンジン |
|-------------|------|-------------|
| **GLB / GLTF** | Web / WebXR / Three.js | Babylon.js / model-viewer |
| **FBX** | 業界標準 | Unity / Unreal / Maya / Blender |
| **OBJ** | 汎用 | Blender / Cinema 4D / 3D printing |
| **USDZ** | Apple AR | iOS Quick Look / Reality Composer |
| **STL** | 3D printing | Cura / PrusaSlicer / Bambu Studio |
| **Blend** | Blender ネイティブ | Blender |

### 競合との差別化

| サービス | text-to-3D | image-to-3D | 商用 mesh 出力 | 速度 |
|---------|-----------|-------------|--------------|------|
| **Meshy** | ✓ | ✓ | ✓ (FBX/GLB) | 1-2 分 |
| Luma AI Genie | ✓ | △ (NeRF) | △ | 1 分 |
| Tripo3D | ✓ | ✓ | ✓ | 30 秒 |
| Stable Fast 3D | △ | ✓ | △ (OSS) | 1 秒 (image only) |
| InstantMesh (OSS) | ✗ | ✓ | △ | 10 秒 |
| Sloyd.ai | ✓ (procedural) | ✗ | ✓ (low-poly) | 5 秒 |

### 利用シーン
- **インディゲーム開発**: 雑魚モンスター・小道具・環境オブジェクトの大量生成
- **VR/AR コンテンツ**: WebXR / Apple Vision Pro 用 3D アセット
- **建築/プロダクト**: コンセプトモデルの素早いプロトタイプ
- **3D printing**: STL 出力で家庭用 3D プリンター向けデータ生成
- **教育**: 化学分子モデル・歴史遺物のビジュアライゼーション
- **EC**: 商品の 3D ビューア用モデル生成

### 注意点 / 制限
- 生成品質はプロンプト次第 (簡単な物体は良好 / 複雑な機械や正確な解剖学は苦手)
- テクスチャ精度は近接撮影に耐えないことがある (中距離視点向け)
- 商用利用: 有料プランは OK (Free プランは個人利用のみ)
- API レート: Pro = 月 200 モデル / Max = 月 600 モデル
- 著作権キャラクター / ブランドロゴの生成は制限

### 料金 (2026年4月時点)
- **Free**: 200 クレジット (約 10 モデル / 個人利用のみ)
- **Pro** ($20/月): 1,000 クレジット (約 200 モデル / 商用 OK)
- **Max** ($60/月): 4,000 クレジット (約 600 モデル / API + 優先処理)
- **Enterprise**: カスタム (チーム共有・SSO・優先サポート)

### API 例
```python
import requests

# Text-to-3D
response = requests.post(
    "https://api.meshy.ai/v1/text-to-3d",
    headers={"Authorization": "Bearer YOUR_API_KEY"},
    json={
        "object_prompt": "a futuristic robot dog with glowing blue eyes",
        "style_prompt": "realistic, high detail, PBR materials",
        "art_style": "realistic",
        "negative_prompt": "low quality, low poly",
    },
)
task_id = response.json()["result"]
# Poll for completion → download GLB/FBX
```

### 公式リソース
- **公式サイト**: https://www.meshy.ai/
- **API ドキュメント**: https://docs.meshy.ai/
- **Discord コミュニティ**: https://discord.gg/meshy
- **Showcase ギャラリー**: https://www.meshy.ai/discover

Meshy は AI 3D 生成カテゴリのリーディングサービスで、ゲーム開発・XR・EC 3D ビューア領域でアセット制作のリードタイムを劇的に短縮する。$$,
  'https://www.meshy.ai/',
  '2026-04-26',
  1
)
ON CONFLICT (provider, category) DO NOTHING;

INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  'AI大学 215→216社化: Meshy 追加',
  'Win版#132 part 24。Meshy (AI 3D モデル生成 / text-to-3D / image-to-3D / GLB/FBX/USDZ / Unity/Unreal 統合 / 8/9) を ai_university_content に追加。',
  '2026-04-26'
)
ON CONFLICT DO NOTHING;
