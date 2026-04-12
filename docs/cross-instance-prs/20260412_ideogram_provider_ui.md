---
from: Windows版
to: VSCode版
date: 2026-04-12
status: pending
---

# Ideogram AI プロバイダー UI 追加依頼

## 背景

Windows版#51 で Ideogram AI を AI大学 33社目として追加しました。
migration: `supabase/migrations/20260412026000_seed_ideogram_ai_university.sql`
provider キー: `ideogram`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` に以下を追加してください。

### 1. `_providerMeta`

```dart
'ideogram': {
  'name': 'Ideogram AI',
  'emoji': '🖼️',
  'color': Color(0xFF6B21A8),  // Ideogram purple
  'description': '画像内テキスト生成 / Magic Prompt',
},
```

### 2. `_fallback`

```dart
'ideogram': '''
# Ideogram AI — 画像内テキスト生成が業界最高精度

Ideogram AIは「画像の中の文字が正確に読める」という他の画像生成AIが
苦手な領域で圧倒的な精度を誇る画像生成サービスです。

## 特徴
- テキスト精度: ポスター・バナーの文字が正確に読める
- Ideogram 2.0: フォトリアル品質・最大2048×2048px
- Magic Prompt: 短いプロンプトを自動で詳細化
- スタイル: DESIGN / REALISTIC / ANIME / 3D_RENDER / WATERCOLOR

## DALL-E・SDとの違い
他のAIは文字が歪む・読めない場合が多いが、Ideogramは
「SALE 50% OFF」「夏祭りポスター」などを正確に生成できる。

[Ideogram API](https://developer.ideogram.ai/)
''',
```

### 3. `_quizzes`

```dart
'ideogram': [
  {
    'question': 'Ideogram AIが他の画像生成AIと比べて特に優れている点は？',
    'options': ['画像内のテキスト (文字) を正確に生成できる', '動画から静止画を高精度に抽出できる', 'リアルタイムで画像をストリーミング生成できる', '音声から画像コンセプトを自動生成できる'],
    'answer': 0,
    'explanation': 'Ideogramの最大の強みは「画像内テキストの精度」です。DALL-E・Stable Diffusion・Midjourneyなどは画像内の文字が歪んだり読めなかったりすることが多いですが、Ideogramはポスター・バナー・ロゴなどの文字入り画像を正確に生成できます。マーケティング資材やSNSバナー制作に特に有効です。',
  },
  {
    'question': 'Ideogramの「Magic Prompt」機能の目的は？',
    'options': ['短いプロンプトをAIが自動で詳細化して生成品質を向上させる', '生成した画像のプロンプトを自動で逆算して表示する', '複数プロンプトを同時実行して最良の結果を選ぶ', '他のAIのプロンプトをIdeogram形式に自動変換する'],
    'answer': 0,
    'explanation': 'Magic Promptは「夏祭りポスター」のような短い入力を、色・雰囲気・スタイル・構図など詳細な英語プロンプトに自動拡張します。プロンプトエンジニアリングの知識がなくても高品質な画像を生成できるIdeogramの差別化機能です。',
  },
],
```

### 4. `_providerEmojis` に `'🖼️'` 追加

## 完了後 `status: done` に変更
