---
from: Windows版
to: VSCode版
date: 2026-04-12
status: done
---

# Nvidia NIM プロバイダー UI 追加依頼

## 背景

Windows版#38 で Nvidia NIM (GPU AI インフラ最大手) を AI大学 15社目として追加しました。
migration 適用済み: `supabase/migrations/20260412006000_seed_nvidia_ai_university.sql`

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に Nvidia を追加してください。

### 1. `_providerMeta` マップに追加

```dart
'nvidia': {
  'name': 'Nvidia',
  'emoji': '🟢',
  'color': Color(0xFF76B900),  // Nvidia brand green
  'description': 'NIM / GPU AI インフラ',
},
```

### 2. `_fallback` マップに追加

```dart
'nvidia': '''
# Nvidia — GPU AI インフラの世界標準

ChatGPT / Gemini / Claude など主要 AI の大半が Nvidia GPU で動いています。
NIM (Inference Microservices) で OpenAI 互換の高速推論 API を提供。

## 主要機能
- NVIDIA NIM: 100+モデルを OpenAI 互換 API で利用
- TensorRT-LLM: 同 GPU で最大 5 倍高速化
- ローカルデプロイ: Docker コンテナで完全オンプレ運用可
- Nemotron-70B: Meta LLaMA3.1 を Nvidia がチューニング

[build.nvidia.com](https://build.nvidia.com/) で無料体験可能
''',
```

### 3. `_quizzes` マップに追加 (任意)

```dart
'nvidia': [
  {
    'question': 'NVIDIA NIM の API は何の API と互換性がありますか？',
    'options': ['OpenAI API', 'Anthropic API', 'Gemini API', '独自 API'],
    'answer': 0,
    'explanation': 'NIM は OpenAI API と互換性があるため、base_url を変更するだけで既存コードがそのまま動きます。',
  },
  {
    'question': 'TensorRT-LLM 最適化により推論速度はおよそ何倍になりますか？',
    'options': ['3〜5倍', '10倍以上', '1.5倍', '2倍'],
    'answer': 0,
    'explanation': 'TensorRT-LLM による最適化で、同一 GPU スペックで 3〜5 倍の推論速度向上が一般的に得られます。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🟢'` を追加（既に追加済みの場合はスキップ）。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
