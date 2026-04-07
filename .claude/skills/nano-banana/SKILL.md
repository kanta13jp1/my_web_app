# Nano Banana Skill — Gemini 画像生成

## 概要

Nano Banana = Google Gemini 画像生成モデル のカジュアルな呼び名。
このスキルにより Claude Code がプロンプトからUI画像・アイコン・OGP画像を生成できる。

## 前提条件

- `GEMINI_API_KEY` 環境変数が設定されていること
- Google AI Studio (https://aistudio.google.com) から無料取得可能

## 使い方

```bash
# 環境変数設定
export GEMINI_API_KEY=your_api_key_here

# 画像生成 (Gemini 2.5 Flash Image)
curl "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-preview-image-generation:generateContent" \
  -H "Content-Type: application/json" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -d '{
    "contents": [{"parts": [{"text": "YOUR_PROMPT_HERE"}]}],
    "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]}
  }'
```

## このプロジェクトでの活用

### OGP画像生成
```
プロンプト例: "自分株式会社のOGP画像。インディゴブルー(#6366F1)のグラデーション背景。
白文字で「21のSaaSを1つに。AI統合ライフ管理アプリ」。シンプルでモダンなデザイン。
1200x630px。"
```

### アプリアイコン生成
```
プロンプト例: "自分株式会社のアプリアイコン。
インディゴブルーのグラデーション背景に、白の人型シルエット+ビル建物のアイコン。
ミニマルでモダン。512x512px。"
```

### UI モックアップ生成
```
プロンプト例: "日本語SaaSのランディングページのヒーローセクション。
Material Design 3スタイル。プライマリカラー#6366F1。
ヘッドライン「Notion・Slack・LINE 21サービスを1つに」。
CTAボタン「無料で始める」。モバイルファースト。"
```

## 料金目安 (Google API)
- 512px: ~$0.045/枚
- 1K px: ~$0.067/枚 (Flash) / $0.134/枚 (Pro)
- 無料枠: 1分15リクエスト、1日1500リクエスト

## 注意事項
- 生成した画像は `web/images/` や `assets/images/` に保存する
- pubspec.yaml の assets セクションに追加を忘れずに
