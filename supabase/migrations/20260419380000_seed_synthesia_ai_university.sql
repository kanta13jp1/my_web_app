-- PS版#3 Session 5: Synthesia — エンタープライズ向け AI アバター動画プラットフォーム
INSERT INTO ai_university_content (provider, category, title, content, published_at)
VALUES
(
  'synthesia',
  'overview',
  'Synthesia — 230+ アバター × 140言語のエンタープライズ AI 動画プラットフォーム',
  E'## Synthesia とは\n\nSynthesia は 2017 年にロンドンで設立されたエンタープライズ向け **AI 動画生成プラットフォーム**。\n「テキストを入力するだけでプロ品質の動画を生成」するアプローチで、撮影・編集の専門知識不要を実現。\n\n2024 年に評価額 $1B のユニコーン認定。KPMG・IHG・Zoom など 50,000+ 社が利用。\n\n## 主な特徴\n\n- **230+ AI アバター**: 多様な人種・性別・スタイルのアバターを標準提供\n- **140 言語**: 1 本の動画を 140 言語に即座に翻訳・吹き替え\n- **Personal Avatar**: 自分の姿を 5 分の録画で AI アバター化\n- **AI スクリプトライター**: プロンプトから動画スクリプトを自動生成\n- **ブランドキット**: ロゴ・カラー・フォントを全動画に一括適用\n\n## 活用事例\n\n- **社員研修動画**: 一度制作してアバターでコンテンツ更新\n- **製品デモ**: 140 言語に自動翻訳で海外展開\n- **カスタマーサポート**: FAQ を動画化して視覚的なサポート提供\n- **L&D (学習・能力開発)**: インタラクティブな学習動画シリーズ',
  '2026-04-19'
),
(
  'synthesia',
  'models',
  'Synthesia 機能・プラン一覧',
  E'## AI アバター\n\n| タイプ | 数 | 内容 |\n|--------|-----|------|\n| **Express Avatars** | 230+ | 事前収録・即利用可能 |\n| **Personal Avatar** | 1体 | 自分の姿を 5 分録画でクローン |\n| **Custom Avatar** | 要相談 | ブランドキャラクター専用作成 |\n\n## 翻訳・音声\n\n- **140言語対応**: 自動翻訳 + 自然な口の動きに同期\n- **Voice Clone**: アバターの声を自分の声にカスタマイズ\n- **音声スタイル**: ニュートラル / 元気 / 落ち着き など\n\n## 動画テンプレート\n\n- 500+ のプロデザインテンプレート\n- 縦型（TikTok/Reels）/ 横型（YouTube）/ 正方形（SNS）\n- カスタムブランドテンプレートの作成・共有\n\n## API 機能\n\n- **動画自動生成**: スクリプト + アバター ID → 動画 URL\n- **一括生成**: CSV で複数動画を同時生成\n- **Webhook**: 生成完了イベントをシステムに通知\n\n## 料金\n\n| プラン | 月額 | 動画数 |\n|--------|------|--------|\n| Free | $0 | 3本/月（透かし付き）|\n| Starter | $29 | 月 10本 |\n| Creator | $89 | 月 30本 |\n| Enterprise | 要相談 | 無制限 + API |\n\n※ API アクセスは Enterprise プランのみ',
  '2026-04-19'
),
(
  'synthesia',
  'api',
  'Synthesia API 使い方',
  E'## 認証\n\n```bash\nexport SYNTHESIA_API_KEY="YOUR_API_KEY"\n```\n\n## 動画生成リクエスト\n\n```python\nimport requests, time\n\nheaders = {\n    "Authorization": f"Bearer {SYNTHESIA_API_KEY}",\n    "Content-Type": "application/json"\n}\n\n# 動画生成\nresponse = requests.post(\n    "https://api.synthesia.io/v2/videos",\n    headers=headers,\n    json={\n        "test": False,\n        "title": "AI大学 紹介動画",\n        "description": "Synthesia API テスト",\n        "visibility": "private",\n        "aspectRatio": "16:9",\n        "slides": [\n            {\n                "script": "こんにちは！自分株式会社の AI 大学へようこそ。110社以上の AI プロバイダーを学べます。",\n                "avatar": "anna_costume1_cameraA",\n                "avatarSettings": {\n                    "voice": "ja-JP-NanamiNeural"\n                },\n                "background": {\n                    "videoUrl": null,\n                    "color": "#1a1a2e"\n                }\n            }\n        ]\n    }\n)\nvideo_id = response.json()["id"]\n\n# ポーリングで完了待ち\nwhile True:\n    result = requests.get(\n        f"https://api.synthesia.io/v2/videos/{video_id}",\n        headers=headers\n    ).json()\n    if result["status"] == "complete":\n        print(result["download"])  # 動画ダウンロード URL\n        break\n    time.sleep(10)\n```\n\n## アバター一覧取得\n\n```python\navatars = requests.get(\n    "https://api.synthesia.io/v2/avatars",\n    headers=headers\n).json()\n\nfor a in avatars["avatars"]:\n    print(f"{a[''id'']} — {a[''name'']}")\n```\n\n## 翻訳 API\n\n```python\n# 既存動画を他言語に翻訳\nrequests.post(\n    f"https://api.synthesia.io/v2/videos/{video_id}/translations",\n    headers=headers,\n    json={"targetLanguages": ["en", "zh", "ko", "es"]}\n)\n```\n\n## 活用シーン\n\n- **AI 大学コンテンツを動画化**: プロバイダー解説を Synthesia で動画生成\n- **多言語展開**: 1 本の日本語動画 → 自動翻訳で 140 言語展開\n- **研修コンテンツ量産**: スクリプト更新のみで動画を低コスト再生成',
  '2026-04-19'
)
ON CONFLICT (provider, category) DO UPDATE SET
  title = EXCLUDED.title,
  content = EXCLUDED.content,
  published_at = EXCLUDED.published_at;
