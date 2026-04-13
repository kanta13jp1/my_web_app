---
date: 2026-04-13
from: Windows版#60
to: VSCode版
status: pending
priority: medium
---

# AI大学 qwen + moonshot プロバイダー UI 追加依頼

## 概要

Windows版#60 で以下の migration を追加済み:
- `20260412036000_seed_qwen_ai_university.sql` — Qwen / Alibaba Cloud (40社目)
- `20260412037000_seed_moonshot_ai_university.sql` — Moonshot AI / Kimi (41社目)

VSCode版にて `gemini_university_v2_page.dart` の `_providerMeta` と `_fallback` マップへの追加をお願いします。

## 追加内容

### `_providerMeta` エントリ

```dart
'qwen': ProviderMeta(
  displayName: 'Qwen (Alibaba)',
  emoji: '🌐',
  color: Color(0xFFFF6A00),  // オレンジ系 (Alibaba カラー)
  description: 'Alibaba Cloud 製多言語LLM・DashScope API',
),
'moonshot': ProviderMeta(
  displayName: 'Moonshot AI',
  emoji: '🌙',
  color: Color(0xFF6366F1),  // インディゴ系 (宇宙・月)
  description: '超長文コンテキスト特化 Kimi AI (128K)',
),
```

### `_fallback` エントリ

```dart
'qwen': '''
## Qwen (Alibaba Cloud)
Alibaba製多言語LLM。Qwen2.5-72BはオープンソースLLM最強クラス。
DashScope APIはOpenAI互換。日本語・中国語・英語29言語対応。無料枠あり。
''',
'moonshot': '''
## Moonshot AI (Kimi)
超長文処理特化。Kimi v1-128kは128Kトークン対応でコスト最安値クラス。
OpenAI SDK互換。PDF/Wordファイルを直接アップロードして処理可能。
''',
```

## 参考

- Qwen: Alibaba Cloud / DashScope API / Qwen2.5-72B はHugging Face公開済み
- Moonshot AI: Kimi / 128K コンテキスト / 200万トークン研究版も公開
