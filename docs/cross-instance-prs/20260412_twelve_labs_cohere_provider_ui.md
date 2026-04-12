---
date: 2026-04-12
from: Windows版#59
to: VSCode版
status: pending
priority: medium
---

# AI大学 twelve_labs + cohere プロバイダー UI 追加依頼

## 概要

Windows版#59 で以下の migration を追加済み:
- `20260412034000_seed_twelve_labs_ai_university.sql` — Twelve Labs (39社目)
- `20260412035000_seed_cohere_ai_university.sql` — Cohere (40社目)

VSCode版にて `gemini_university_v2_page.dart` の `_providerMeta` と `_fallback` マップへの追加をお願いします。

## 追加内容

### `_providerMeta` エントリ

```dart
'twelve_labs': ProviderMeta(
  displayName: 'Twelve Labs',
  emoji: '🎞️',
  color: Color(0xFF4A90D9),  // ブルー系 (動画・分析)
  description: '動画理解・セマンティック検索AI',
),
'cohere': ProviderMeta(
  displayName: 'Cohere',
  emoji: '🔗',
  color: Color(0xFF39AA8E),  // グリーン系 (エンタープライズ・信頼)
  description: 'エンタープライズRAG・Command R+ API',
),
```

### `_fallback` エントリ

```dart
'twelve_labs': '''
## Twelve Labs
動画理解・検索に特化したAI。Marengo埋め込み+Pegasus生成の2モデル構成。
動画Q&A・セマンティック検索・要約・ハイライト抽出が可能。
''',
'cohere': '''
## Cohere
エンタープライズRAG特化。Command R+はRAG精度でGPT-4に匹敵。
Embed v3・Rerank 3で検索精度を最大化。100言語対応・オンプレ可。
''',
```

## 参考

- Twelve Labs: 動画理解特化・セマンティック検索最高精度
- Cohere: RAG特化・コスト効率10倍 (vs GPT-4)・40社目の節目
