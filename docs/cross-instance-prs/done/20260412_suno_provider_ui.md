---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Suno AI プロバイダー UI 追加依頼

## 背景

Windows版#50 で Suno AI を AI大学 32社目として追加しました。
migration 適用済み: `supabase/migrations/20260412023000_seed_suno_ai_university.sql`

provider キー: `suno`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` に以下を追加してください。

### 1. `_providerMeta`

```dart
'suno': {
  'name': 'Suno AI',
  'emoji': '🎵',
  'color': Color(0xFF1C1C2E),  // Suno dark purple
  'description': '音楽生成AI / ボーカル+楽曲を完全生成',
},
```

### 2. `_fallback`

```dart
'suno': '''
# Suno AI — テキストから完全楽曲を生成する音楽AI

Suno AIはテキストのプロンプトから、ボーカル・伴奏・ミックスが完成した
楽曲を数十秒で生成します。月間100万人以上が利用しています。

## 特徴
- テキスト→完全楽曲 (ボーカル+伴奏+ミックス)
- 日本語歌詞の楽曲生成に対応
- ポップ・ロック・EDM・ジャズ・演歌など多ジャンル
- カスタム歌詞指定可能
- v4モデルで大幅な音質向上

## プロンプト例
"emotional japanese jazz song about autumn rain, female vocalist, piano and bass, slow tempo"
→ 30秒で完成楽曲を生成！

[Suno AI](https://suno.com/)
''',
```

### 3. `_quizzes`

```dart
'suno': [
  {
    'question': 'Suno AIで生成される楽曲に含まれるものは？',
    'options': ['ボーカル・伴奏・ミックス・マスタリングが全て含まれる完全楽曲', 'メロディーのMIDIデータのみ', '歌詞テキストと楽譜のみ', '伴奏のみ (ボーカルは別途録音が必要)'],
    'answer': 0,
    'explanation': 'Suno AIは「完全楽曲生成」が最大の特徴です。AIボーカル・楽器演奏・ミックス・マスタリングまで全てが含まれた完成品のMP3/WAVファイルが出力されます。音楽の知識がなくても、プロ品質の楽曲を作れます。',
  },
  {
    'question': 'Suno AIのFreeプランで月間生成できる楽曲数は？',
    'options': ['約10曲 (50クレジット / 1曲=5クレジット)', '無制限 (速度制限あり)', '1曲のみ (試用版)', '約100曲 (広告視聴で追加可)'],
    'answer': 0,
    'explanation': 'Suno AIのFreeプランは月間50クレジットが付与されます。1回の生成で2バリエーションが作られ5クレジット消費するため、月約10曲を生成できます。商用利用はProプラン ($10/月・約500曲) 以上が必要です。',
  },
],
```

### 4. `_providerEmojis` に `'🎵'` 追加

## 完了後 `status: done` に変更
