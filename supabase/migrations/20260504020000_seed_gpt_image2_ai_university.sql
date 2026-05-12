-- PS#4 S671: AI大学 GPT-Image-2 画像生成AI学科追加 (Issue #1889)
-- Source: NotebookLM 2ee2ea76 Mastering GPT-Image-2

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'openai', 'image_generation',
  'GPT-Image-2 — プロンプトエンジニアリング完全ガイド (10/10)',
  $$## GPT-Image-2 とは

**GPT-Image-2** は OpenAI が 2025 年にリリースした最新画像生成モデル。
DALL-E 3 の後継として、テキストレンダリング・プロンプト忠実度・スタイル多様性が大幅強化された。

GPT-4o に統合され API でも単独利用が可能。**Responses API** で `gpt-image-2` モデルを指定すると
高品質な画像を生成・編集・バリエーション生成できる。

## 主要API

```
[画像生成 — /v1/images/generations]
  model: "gpt-image-2"
  prompt: <テキストプロンプト>
  n: 1〜10 (生成枚数)
  size: "1024x1024" | "1792x1024" | "1024x1792"
  quality: "standard" | "hd"
  response_format: "url" | "b64_json"

[画像編集 — /v1/images/edits]
  image: <元画像>
  mask: <編集マスク (透明部分を編集)>
  prompt: <編集指示>

[バリエーション — /v1/images/variations]
  image: <元画像>
  n: 1〜10
```

## プロンプトエンジニアリング 5原則

### 原則1: 被写体 → スタイル → 雰囲気 → 技術的仕様
```
悪い例: "猫の絵"
良い例: "orange tabby cat sitting on a windowsill, watercolor style,
         soft afternoon light, 8k resolution, highly detailed"
```

### 原則2: 負の条件より正の指定を優先
```
悪い例: "ぼやけていない、暗くない写真"
良い例: "sharp focus, bright studio lighting, professional photography"
```

### 原則3: テキスト埋め込みは引用符で明示
```
"a poster with the text 'Hello, World!' in bold red letters"
→ GPT-Image-2 は看板・ロゴ・タイポグラフィを高精度で生成可能
```

### 原則4: スタイル参照でアーティスト・メディアを指定
```
"in the style of Studio Ghibli" / "photorealistic 35mm film"
"ukiyo-e woodblock print" / "Bauhaus design poster"
```

### 原則5: 構図・視点・照明の明示
```
"bird's eye view" / "close-up portrait" / "rule of thirds"
"golden hour lighting" / "high-key lighting" / "chiaroscuro"
```

## Flutter Web 画像生成UI設計パターン

```dart
// Supabase Edge Function 経由で GPT-Image-2 を呼び出す
// EF: ai-assistant (既存EFに action 追加)

class ImageGeneratorPage extends StatefulWidget {
  @override
  State<ImageGeneratorPage> createState() => _ImageGeneratorPageState();
}

class _ImageGeneratorPageState extends State<ImageGeneratorPage> {
  final _promptController = TextEditingController();
  String? _imageUrl;
  bool _loading = false;

  Future<void> _generate() async {
    setState(() => _loading = true);
    // Edge Function呼び出し
    final response = await supabase.functions.invoke(
      'ai-assistant',
      body: {
        'action': 'image.generate',
        'prompt': _promptController.text,
        'size': '1024x1024',
        'quality': 'standard',
      },
    );
    setState(() {
      _imageUrl = response.data['url'];
      _loading = false;
    });
  }
}
```

## Supabase Storage 連携アーキテクチャ

```
[生成フロー]
1. ユーザープロンプト入力
2. Flutter → Supabase Edge Function (ai-assistant:image.generate)
3. Edge Function → OpenAI Responses API
4. 生成画像URL取得
5. 画像をSupabase Storage (bucket: ai-generated-images) に保存
6. 永続URLをDBに記録 → Flutter で表示

[ストレージ設計]
bucket: ai-generated-images
├── {user_id}/
│   ├── {timestamp}_{prompt_hash}.png
│   └── metadata.json
RLS: owner のみ読み書き可
```

## 日本語プロンプト対応

GPT-Image-2 は日本語プロンプトを直接理解するが、
英語プロンプトの方が高品質な結果を得やすい。

**推奨**: Claude/GPT-4o で日本語プロンプト→英語最適化プロンプトに翻訳してから生成。

```
ユーザー入力: "夕焼けの富士山"
Claude変換: "Mount Fuji at sunset, dramatic orange and pink sky,
            reflection on Lake Kawaguchi, ultra-detailed photograph,
            golden hour, 8k"
```

## コスト管理

| サイズ | standard | hd |
|--------|----------|-----|
| 1024x1024 | $0.040/枚 | $0.080/枚 |
| 1792x1024 | $0.080/枚 | $0.120/枚 |
| 1024x1792 | $0.080/枚 | $0.120/枚 |

**最適化**: Prompt Caching は画像生成APIには適用不可。
バッチ生成 (n>1) で1リクエストのオーバーヘッドを削減。
$$,
  'https://platform.openai.com/docs/guides/image-generation',
  '2026-05-04',
  940
)
ON CONFLICT (provider, category) DO NOTHING;
