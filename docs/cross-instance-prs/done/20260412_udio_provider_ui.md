---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Udio プロバイダー UI 追加依頼

## 背景

Windows版#51 で Udio を AI大学 34社目として追加しました。
migration: `supabase/migrations/20260412027000_seed_udio_ai_university.sql`
provider キー: `udio`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` に以下を追加してください。

### 1. `_providerMeta`

```dart
'udio': {
  'name': 'Udio',
  'emoji': '🎸',
  'color': Color(0xFF1A1A2E),  // Udio dark navy
  'description': '音楽生成AI / 音楽理論忠実・Extend機能',
},
```

### 2. `_fallback`

```dart
'udio': '''
# Udio — 音楽理論に忠実な高品質音楽生成AI

UdioはSunoと並ぶ音楽生成AIの双璧。元Google DeepMindのメンバーが創業し、
音楽的精度を重視した設計が特徴です。

## Sunoとの違い
- インストゥルメンタル品質: Udio ★★★★★ > Suno ★★★★
- 音楽理論精度: Udio ★★★★★ > Suno ★★★★
- ボーカル自然さ: Suno ★★★★★ > Udio ★★★★

## Extend機能
生成した32秒の楽曲を前後に自然延長 → 10分以上のBGMも作成可能

## 用途
- BGM・環境音楽: Udio推奨 (コード進行が正確)
- J-POPボーカル曲: Suno推奨 (ボーカルが自然)

[Udio](https://www.udio.com/)
''',
```

### 3. `_quizzes`

```dart
'udio': [
  {
    'question': 'UdioがSunoより優れているとされる領域は？',
    'options': ['インストゥルメンタル生成と音楽理論の精度 (コード進行・拍子の正確さ)', '日本語ボーカルの自然さと発音の正確さ', '短い楽曲フレーズの高速生成速度', '無料プランでの月間生成可能曲数'],
    'answer': 0,
    'explanation': 'UdioはSunoと比べて「音楽理論に忠実な生成」が強みです。ジャズのコード進行、クラシックの対位法、複雑な拍子 (7/8拍子など) など、音楽的に正確な楽曲を生成します。反対に自然なボーカルや日本語歌詞はSunoの方が得意です。',
  },
  {
    'question': 'UdioのExtend機能の主な用途は？',
    'options': ['32秒の生成楽曲を前後に自然延長して長尺BGMを作成する', '楽曲のテンポを自動で2倍に伸ばしてスローバージョンを作る', '複数の楽曲を自動でミックスしてメドレーを作成する', '他のAIが生成した音楽をUdioスタイルに変換する'],
    'answer': 0,
    'explanation': 'ExtendはUdio独自の機能で、生成した32秒のセグメントを前後に自然に延長します。「イントロ→Aメロ→Bメロ→サビ→アウトロ」という楽曲構成を複数のExtend操作で構築でき、最終的に10分以上の完全なBGMトラックを作成できます。',
  },
],
```

### 4. `_providerEmojis` に `'🎸'` 追加

## 完了後 `status: done` に変更
