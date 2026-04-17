---
date: 2026-04-17
from: Windowsアプリ版#72
to: VSCode版
status: pending
priority: medium
---

# Inception Labs (Mercury) + World Labs (Fei-Fei Li) の UI追加依頼

## 概要

AI大学 75-76社目として、2026年最新フロンティア AI 2社を追加。

- **Inception Labs**: 世界初の商用拡散LLM (Mercury 2 / 史上最速Reasoning LLM)
- **World Labs**: Fei-Fei Li 創業・空間知能 (3D 世界生成 / Large World Models)

VSCode版で `lib/pages/gemini_university_v2_page.dart` の以下2箇所に追記してください。

## 追加内容

### 1. `_providerMeta` マップへの追記

```dart
'inception_labs': _ProviderMeta(
  name: 'Inception (Mercury)',
  emoji: '💨',
  color: const Color(0xFF00BFA5), // 高速性 → ティール
  officialUrl: 'https://www.inceptionlabs.ai/',
),
'world_labs': _ProviderMeta(
  name: 'World Labs',
  emoji: '🌍',
  color: const Color(0xFF2E7D32), // 3D世界 → 深緑
  officialUrl: 'https://www.worldlabs.ai/',
),
```

### 2. `_fallback` マップへの追記

```dart
'inception_labs': '''
# Inception Labs (Mercury)

世界初の商用 **拡散 LLM (dLLM)**。トークン並列生成で従来 LLM より 5〜10倍高速。

- **Mercury 2** (2026/02): 史上最速の Reasoning LLM
- 128K context / OpenAI互換API
- Free tier: 10M tokens/月
- Azure AI Foundry 提供
- 公式: https://www.inceptionlabs.ai/
''',
'world_labs': '''
# World Labs

Fei-Fei Li (AIの母) 創業。**Large World Models (LWM)** で 3D 世界を生成する空間知能 AI。

- **World API** (2026/01): テキスト/画像/動画→3D 世界
- USD / glTF など業界標準フォーマット出力
- $1B 調達・Embodied AI/ロボット訓練支援
- 公式: https://www.worldlabs.ai/
''',
```

### 3. (任意) クイズ追加

```dart
'inception_labs': [
  _QuizItem(
    question: 'Inception Labs の Mercury が採用する革新的な LLM アーキテクチャは?',
    options: ['Autoregressive Transformer', 'Diffusion LLM (dLLM)', 'Mixture of Experts', 'State Space Model'],
    correctIndex: 1,
    explanation: '拡散 (Diffusion) により全トークンを並列生成する世界初の商用 dLLM。',
  ),
],
'world_labs': [
  _QuizItem(
    question: 'World Labs を創業した研究者で「AIの母」と呼ばれる人物は?',
    options: ['Geoffrey Hinton', 'Yann LeCun', 'Fei-Fei Li', 'Andrew Ng'],
    correctIndex: 2,
    explanation: 'Fei-Fei Li はスタンフォード教授でImageNetの生みの親。Spatial Intelligence を提唱。',
  ),
],
```

## 確認事項

- `flutter analyze` で 0 エラーを維持
- 関連 migration: `20260417100000_seed_inception_labs_ai_university.sql` + `20260417101000_seed_world_labs_ai_university.sql`

## 完了後の対応

このファイルを `docs/cross-instance-prs/done/` に移動してマージしてください。
