# cross-instance-pr: midjourney + hailuo UI追加

作成: Windows版#61 (2026-04-13)
宛先: VSCode版 + PowerShell版
状態: pending

---

## VSCode版 への依頼: `gemini_university_v2_page.dart` UI追加

`lib/pages/gemini_university_v2_page.dart` の `_providerMeta` マップと `_fallback` マップに以下を追加してください。

### `_providerMeta` への追加

```dart
'midjourney': ProviderMeta(
  displayName: 'Midjourney',
  emoji: '🎨',
  color: Color(0xFF000000),
),
'hailuo': ProviderMeta(
  displayName: 'Hailuo AI',
  emoji: '🎬',
  color: Color(0xFF0066FF),
),
```

### `_fallback` マップへの追加

```dart
'midjourney': '''## Midjourney とは
画像生成AIの代名詞。Discordボット/Web版でテキストから高品質画像を生成。
V6/V7・Niji(アニメ特化)・Omni Referenceなどのモデルを提供。
1,600万人超の有料ユーザーを持つ。

公式: https://www.midjourney.com/''',

'hailuo': '''## Hailuo AI (MiniMax) とは
MiniMaxが開発するマルチモーダルAI。動画生成・音声合成・テキスト生成をAPI提供。
Director Model (カメラワーク制御) と Subject Reference (キャラクター維持) が特徴。

公式: https://hailuoai.com/''',
```

### `_quizzes` マップへの追加 (任意)

```dart
'midjourney': [
  QuizQuestion(
    question: 'Midjourneyが主に利用するプラットフォームはどれですか？',
    options: ['Discord', 'Slack', 'Twitter', 'Reddit'],
    correctIndex: 0,
    explanation: 'MidjourneyはDiscordボット経由での利用が中心。Web版(alpha)も提供中。',
  ),
  QuizQuestion(
    question: 'Midjourneyのアニメ・マンガ特化モデルの名前は？',
    options: ['Niji', 'Anime', 'Manga', 'Kawaii'],
    correctIndex: 0,
    explanation: 'Niji (にじ) はアニメ・イラスト生成に特化したMidjourneyのモデル。',
  ),
],
'hailuo': [
  QuizQuestion(
    question: 'Hailuo AIを開発している中国企業はどこですか？',
    options: ['MiniMax', 'ByteDance', 'Baidu', 'Alibaba'],
    correctIndex: 0,
    explanation: 'Hailuo AIは上海のMiniMax社が開発するマルチモーダルAIプラットフォーム。',
  ),
  QuizQuestion(
    question: 'MiniMaxのLLMモデルが対応する最大コンテキスト長は？',
    options: ['100万トークン', '20万トークン', '32Kトークン', '128Kトークン'],
    correctIndex: 0,
    explanation: 'MiniMax-Text-01は100万トークンのコンテキストウィンドウに対応している。',
  ),
],
```

---

## PowerShell版 への依頼: `ai-university-update.yml` プロバイダー追加

`.github/workflows/ai-university-update.yml` の `# 新規追加時は upsert_provider 行を追加する` コメントの直前に以下を追加してください:

```bash
# Midjourney / Hailuo は公式RSSなし → 静的seedコンテンツを維持
# (GH Actions RSS更新対象外)
```

また、ファイル冒頭のプロバイダーリストコメント (line 4) を更新:
- `現在41社` → `現在43社`
- リストの末尾に `midjourney/hailuo` を追加

---

## 根拠

- migrations: `20260413038000_seed_midjourney_ai_university.sql` (42社目)
- migrations: `20260413039000_seed_hailuo_ai_university.sql` (43社目)
- Midjourney: 画像生成AIの代名詞。1,600万人超の有料ユーザー
- Hailuo AI: 動画AI分野で急成長中のMiniMax製プラットフォーム。APIも国際提供済み
