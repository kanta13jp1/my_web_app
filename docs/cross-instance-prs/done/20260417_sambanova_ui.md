---
date: 2026-04-17
from: Windowsアプリ版#74
to: VSCode版
status: pending
priority: medium
---

# SambaNova の UI追加依頼

## 概要

AI大学 78社目として、**SambaNova** を追加。

- **SambaNova**: RDU (Reconfigurable Dataflow Unit) アーキテクチャで GPU 依存なし
- **SN50チップ**: 競合比 5倍高速・3倍コスト効率 (2026-02リリース)
- $350M追加調達・Intel 提携 (2026-03)
- OpenAI API 互換・Llama 405B 200+ tok/s

VSCode版で `lib/pages/gemini_university_v2_page.dart` の以下2箇所に追記してください。

## 追記内容

### 1. `_providerMeta` マップ

```dart
'sambanova': _ProviderMeta(
  label: 'SambaNova',
  icon: '⚡',
  primaryColor: Color(0xFFE03E3E),
),
```

(色は公式ロゴの赤系。適宜 docs/DESIGN.md の orange+indigo トークンへ調整可)

### 2. `_fallback` マップ

```dart
'sambanova': '''
# SambaNova

RDU (Reconfigurable Dataflow Unit) 型 AI 推論チップで、
GPU 比 5倍高速・3倍コスト効率を実現する米国スタートアップ。

## 主要技術
- SN50 チップ (2026-02 リリース)
- SambaNova Cloud (OpenAI 互換 API)
- Llama 405B を 200+ tokens/sec で提供

## 強み
- 開発者 Free Tier \$5 credit
- Meta / AWS / Intel 戦略提携
- オンプレミス SambaNova Suite
''',
```

### 3. `_quizzes` マップ (任意)

```dart
'sambanova': [
  _Quiz(
    question: 'SambaNova の独自チップ設計思想は？',
    options: ['GPU', 'TPU', 'RDU (Reconfigurable Dataflow Unit)', 'NPU'],
    correctIndex: 2,
  ),
  _Quiz(
    question: 'SN50 チップは競合比で何倍の推論速度？',
    options: ['2倍', '3倍', '5倍', '10倍'],
    correctIndex: 2,
  ),
],
```

## 登録済みプロバイダー

migration は commit 済み (`supabase/migrations/20260417170000_seed_sambanova_ai_university.sql`).
CLAUDE.md / COMPRESSED_PROMPT_V3.md / ai-university-update.yml も更新済み。

78社達成。VSCode版で UI 同期後、`done/` に移動してください。
