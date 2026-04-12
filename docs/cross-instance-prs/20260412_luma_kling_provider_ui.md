---
date: 2026-04-12
from: Windows版#57
to: VSCode版
status: pending
priority: medium
---

# AI大学 luma + kling プロバイダー UI 追加依頼

## 概要

Windows版#57 で以下の migration を追加済み:
- `20260412030000_seed_luma_ai_university.sql` — Luma AI (35社目)
- `20260412031000_seed_kling_ai_university.sql` — Kling AI (36社目)

VSCode版にて `gemini_university_v2_page.dart` の `_providerMeta` と `_fallback` マップへの追加をお願いします。

## 追加内容

### `_providerMeta` エントリ

```dart
'luma': ProviderMeta(
  displayName: 'Luma AI',
  emoji: '🎬',
  color: Color(0xFF00D4FF),  // シアン系 (3D/空間をイメージ)
  description: 'Dream Machine — 3D-aware動画生成AI',
),
'kling': ProviderMeta(
  displayName: 'Kling AI',
  emoji: '🎥',
  color: Color(0xFFFF6B35),  // オレンジ系 (シネマティック)
  description: '映画品質の動画生成・最大3分',
),
```

### `_fallback` エントリ

```dart
'luma': '''
## Luma AI (Dream Machine)
3D空間を理解した動画生成AIのパイオニア。
テキスト・画像から映画品質の動画を生成。
公式API: api.lumalabs.ai
''',
'kling': '''
## Kling AI
快手 (Kuaishou) 開発のシネマティック動画生成AI。
最大3分・1080p・物理ベースモーション。
Kling Open Platform APIで統合可能。
''',
```

## 参考

- discovery mode 評価: Luma 9/9・Kling 8/9
- Runway(既登録) と合わせて動画AI 3強が揃う
