---
date: 2026-04-17
from: Windowsアプリ版#71
to: VSCode版
status: pending
priority: medium
---

# Tencent (Hunyuan) + ByteDance (Doubao) の UI追加依頼

## 概要

AI大学 73-74社目として **Tencent Hunyuan** と **ByteDance Doubao** のmigrationを追加済み。
中国 BAT (Baidu/Alibaba/Tencent) の Tencent と、TikTok運営の ByteDance を追加し、
中国主要 AI 企業のカバレッジを完成。

VSCode版で `lib/pages/gemini_university_v2_page.dart` の以下2箇所に追記してください。

## 追加内容

### 1. `_providerMeta` マップへの追記

```dart
'tencent': _ProviderMeta(
  name: 'Tencent Hunyuan',
  emoji: '🐉',
  color: const Color(0xFF1E88E5), // Tencent ブルー
  officialUrl: 'https://hunyuan.tencent.com/',
),
'bytedance': _ProviderMeta(
  name: 'ByteDance Doubao',
  emoji: '🎵',
  color: const Color(0xFF000000), // TikTok ブラック
  officialUrl: 'https://www.doubao.com/',
),
```

### 2. `_fallback` マップへの追記

```dart
'tencent': '''
# Tencent Hunyuan

中国 Tencent の AI 基盤モデルブランド。テキスト・画像・動画・3D の全モダリティでオープンソース最大級のモデルを公開。

- **Hunyuan-Large**: 389B MoE LLM (256K context)
- **Hunyuan Image 3.0**: 80B 世界最大OSS画像モデル
- **HunyuanVideo**: 13B+ OSS動画モデル
- **Hunyuan 3D 2.0**: 1枚画像→3D生成
- 公式: https://hunyuan.tencent.com/
''',
'bytedance': '''
# ByteDance Doubao

TikTok運営 ByteDance の AI ブランド。**Doubao 2.0** (2026/02) は「Agent Era」特化の次世代モデル。

- **Seed 2.0 Pro/Lite/Mini/Code**: 4種類の基盤モデル
- **Seedance 2.0**: TikTok統合動画生成
- 業界最安値級 API (GPT-5.2比 3.7倍安)
- 公式: https://www.doubao.com/
''',
```

### 3. (任意) クイズ追加

```dart
'tencent': [
  _QuizItem(
    question: 'Tencent Hunyuan-Large のコンテキスト長は?',
    options: ['32K', '128K', '256K', '1M'],
    correctIndex: 2,
    explanation: 'Hunyuan-Large は 389B MoE で 256K コンテキスト対応。',
  ),
],
'bytedance': [
  _QuizItem(
    question: 'ByteDance Seed 2.0 が採用する主要設計コンセプトは?',
    options: ['超大規模パラメータ', 'Agent Era (自律タスク実行)', 'マルチランゲージ特化', '長コンテキスト'],
    correctIndex: 1,
    explanation: 'Doubao 2.0 / Seed 2.0 は "Agent Era" を掲げ多段階タスク自律実行を強化。',
  ),
],
```

## 確認事項

- `flutter analyze` で 0 エラーを維持すること
- DB駆動のため `_providerMeta` 追加だけでもタブは生成される
- 関連 migration: `supabase/migrations/20260417098000_seed_tencent_ai_university.sql` + `20260417099000_seed_bytedance_ai_university.sql`

## 完了後の対応

このファイルを `docs/cross-instance-prs/done/` に移動してマージしてください。
