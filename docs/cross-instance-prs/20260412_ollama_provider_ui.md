---
from: Windows版
to: VSCode版
date: 2026-04-12
status: pending
---

# Ollama プロバイダー UI 追加依頼

## 背景

Windows版#49 で Ollama を AI大学 30社目として追加しました。
migration 適用済み: `supabase/migrations/20260412021000_seed_ollama_ai_university.sql`

Note: provider キーは `ollama` です。

## 依頼内容

`lib/pages/gemini_university_v2_page.dart` の以下の3箇所に追加してください。

### 1. `_providerMeta` マップに追加

```dart
'ollama': {
  'name': 'Ollama',
  'emoji': '🦙',
  'color': Color(0xFF1A1A1A),  // Ollama brand dark
  'description': 'ローカルLLM実行 / 完全プライバシー保護',
},
```

### 2. `_fallback` マップに追加

```dart
'ollama': '''
# Ollama — プライバシー完全保護のローカルLLM実行ツール

Ollamaは自分のPC/サーバー上でLLaMA・Gemma・Mistral・DeepSeekなどの
オープンソースLLMをローカル実行するツールです。

## 特徴
- データが外部に一切送信されない (完全プライバシー)
- OpenAI SDK互換API (localhost:11434/v1)
- ワンコマンド起動: ollama run llama3.2
- 無料・無制限 (API料金ゼロ)

## 主要モデル
- llama3.3 (70B) — Meta製・多言語高性能
- qwen2.5 (7B) — Alibaba製・日本語強
- gemma2 (9B) — Google製・バランス型
- codellama / deepseek-coder-v2 — コード生成特化

## 活用場面
- 医療・法務などの機密データ処理
- 社内文書のローカルRAG構築
- API料金ゼロで大量テスト

[Ollama 公式](https://ollama.com/)
''',
```

### 3. `_quizzes` マップに追加

```dart
'ollama': [
  {
    'question': 'Ollamaの最大の特徴・メリットは何か？',
    'options': ['データが外部送信されず完全にローカル実行 → プライバシー保護 + API料金ゼロ', 'クラウド上で最新GPT-4より高い精度を提供', 'リアルタイムでWebを検索して最新情報を取得', '1秒以内の超高速レスポンスを保証'],
    'answer': 0,
    'explanation': 'Ollamaの最大の価値は「完全ローカル実行」です。医療・法務・金融などの機密データをクラウドに送信せずAI処理できます。また、API料金が完全に不要なため大量のテスト・バッチ処理も無料で実施できます。',
  },
  {
    'question': 'Ollamaの日本語処理に強いモデルは？',
    'options': ['qwen2.5 (Alibaba製) — 中国語・日本語が特に強い多言語モデル', 'codellama — コード生成に特化した日本語モデル', 'llama3.2 1B — 最軽量だが日本語最強', 'starcoder2 — GitHubのコードデータで学習した日本語モデル'],
    'answer': 0,
    'explanation': 'Ollamaで日本語を使う場合、Alibaba製のqwen2.5 (7B〜72B) が最も品質が高いとされています。llama3.3 (70B) も多言語対応で日本語品質は良好ですが、モデルサイズが大きくGPUが必要です。軽量・日本語ならqwen2.5:7bが実用的な選択です。',
  },
],
```

### 4. `_providerEmojis` リスト更新

`lib/widgets/ai_university_home_card.dart` の `_providerEmojis` に `'🦙'` を追加。

## 完了後

このファイルの `status: pending` を `status: done` に変更してください。
