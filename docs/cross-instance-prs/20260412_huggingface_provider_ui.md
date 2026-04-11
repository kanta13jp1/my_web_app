---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Hugging Face プロバイダー UI 追加依頼

## 背景

Windows版#37 で Hugging Face (OSS AI モデルハブ最大) を AI大学 14社目として追加しました。
migration 適用済み: `supabase/migrations/20260412005000_seed_huggingface_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Hugging Face を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'huggingface': {
  'name': 'Hugging Face',
  'emoji': '🤗',
  'color': Color(0xFFFFD21E),  // Hugging Face brand yellow
  'description': 'OSS モデルハブ最大',
},
```

### 2. `_fallback` マップに追加

```dart
'huggingface': '''
# Hugging Face — OSS AI モデルの GitHub

100万以上の AI モデルをホスティングする世界最大のモデルハブ。
LLaMA / Mistral / FLUX / Whisper など主要 OSS モデルが全て入手可能。

## 主要機能
- Hub: 100万+ モデル・50万+ データセット (多くは商用可)
- Transformers: BERT/GPT/LLaMA を統一 API で利用
- Inference API: クラウドでモデルを即利用 (無料枠あり)
- Spaces: Gradio/Streamlit でデモアプリ公開
- 日本語モデル: rinna / ELYZA / CyberAgent / llm-jp など

[Hugging Face Hub](https://huggingface.co/)
''',
```

### 3. `_quizzes` マップに追加 (任意)

```dart
'huggingface': [
  {
    'question': 'Hugging Face Hub に登録されているモデル数はおよそ何個ですか？',
    'options': ['100万以上', '1万以上', '10万以上', '1000以上'],
    'answer': 0,
    'explanation': '2026年時点で Hugging Face Hub には 100万以上のモデルが公開されており、毎日数千のモデルが追加されています。',
  },
  {
    'question': 'Hugging Face の transformers ライブラリが対応するフレームワークは？',
    'options': ['PyTorch と TensorFlow 両方', 'PyTorch のみ', 'TensorFlow のみ', 'JAX のみ'],
    'answer': 0,
    'explanation': 'transformers ライブラリは PyTorch・TensorFlow・JAX の全てに対応しており、フレームワーク間の変換も容易です。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🤗'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
