---
date: 2026-04-12
from: Windows版#58
to: VSCode版
status: done
priority: medium
---

# AI大学 pika + assemblyai プロバイダー UI 追加依頼

## 概要

Windows版#58 で以下の migration を追加済み:
- `20260412032000_seed_pika_ai_university.sql` — Pika Labs (37社目)
- `20260412033000_seed_assemblyai_ai_university.sql` — AssemblyAI (38社目)

VSCode版にて `gemini_university_v2_page.dart` の `_providerMeta` と `_fallback` マップへの追加をお願いします。

## 追加内容

### `_providerMeta` エントリ

```dart
'pika': ProviderMeta(
  displayName: 'Pika Labs',
  emoji: '⚡',
  color: Color(0xFF6C63FF),  // パープル系 (速さ・モダン)
  description: '低コスト高速動画生成 $0.03/生成',
),
'assemblyai': ProviderMeta(
  displayName: 'AssemblyAI',
  emoji: '🎙️',
  color: Color(0xFF00BFA5),  // ティール系 (音声・波形)
  description: '音声認識・転写・LeMUR音声理解API',
),
```

### `_fallback` エントリ

```dart
'pika': '''
## Pika Labs
消費者向け動画生成AI。$0.03/生成の低コストが強み。
Pika 2.2で1080p・最大10秒の動画生成が可能。
公式API: api.pika.art
''',
'assemblyai': '''
## AssemblyAI
音声認識・転写・音声理解のリーディングAPI。
Universal-2モデル・99言語対応・LeMURでLLM連携。
Claude (Anthropic) をデフォルトで採用している。
''',
```

## 参考

- Pika: discovery mode 7/9 (Consumer API・低コスト)
- AssemblyAI: discovery mode 6/9 (音声AI特化・LeMUR連携)
- 動画AI 4強完成: Runway / Luma / Kling / Pika
