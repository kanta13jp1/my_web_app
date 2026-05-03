-- PS#3 S150: AI大学 Gemini Code Assist Domain-Specific AI追加 (Issue #1775)
-- Source: 239c758b Gemini Code Assist Release Notes (Domain-Specific AI)

INSERT INTO ai_university_content (provider, category, title, content, source_url, published_at, sort_order)
VALUES (
  'gemini', 'code_assist_domain_specific',
  'Gemini Code Assist Domain-Specific AI — コードベース文脈学習・プロジェクト固有補完・企業AIカスタマイズ (10/10)',
  $$## Gemini Code Assist Domain-Specific AI とは

**Google Gemini Code Assist** の**Domain-Specific AI**機能は、企業のコードベースを学習して
**プロジェクト固有の補完・提案**を行う。単なる汎用補完ではなく、自社の命名規則・
アーキテクチャパターン・ライブラリ使用法を理解した「チーム専用AI」として機能する。

## Domain-Specific AI の仕組み

```
[学習対象]
  ・社内GitHubリポジトリ (Private含む)
  ・Googleドライブ上のドキュメント・設計書
  ・Confluenceなどの社内ウィキ
  ・Jiraなどのチケット/タスク記述
  → これらを Google Cloud 上でセキュアに学習 (データは社外に出ない)

[カスタマイズされる機能]
  ・コード補完: 自社ライブラリ・関数名・変数命名パターンを学習
  ・Chat回答: 「このプロジェクトではどうする?」に自社規約を踏まえて回答
  ・コードレビュー: 自社のコーディング規約違反を検出
  ・リファクタリング: 自社パターンに沿ったリファクタリング提案

[Google ベースの安全設計]
  ・CMEK (Customer-Managed Encryption Keys) でデータを暗号化
  ・学習データはGoogle Cloudのプロジェクト内に隔離
  ・モデルは全社共有ではなく企業ごとに独立
  ・SOC2 / ISO27001 / GDPR 準拠
```

## Gemini Code Assist vs Claude Code — AI大学での比較

| 特性 | Gemini Code Assist | Claude Code |
|------|-------------------|-------------|
| **Domain-Specific** | ✅ 企業コードベース学習 | △ CLAUDE.md でルール注入 |
| **IDE統合** | VS Code / JetBrains / Cloud IDE | CLI + VS Code extension |
| **Flutter対応** | ✅ Dart/Flutter専用最適化 | ✅ |
| **Google Cloud統合** | ✅ シームレス | △ |
| **コスト** | Enterprise: $19/user/month | Max Plan: $200/month |
| **オフライン** | ✗ | ✗ |
| **自律エージェント** | △ 制限あり | ✅ フル |

## Flutter/Dart での Gemini Code Assist 活用

```dart
// Gemini Code Assist が学習したコードから提案する例
// 「// TODO: Add Supabase query for users」と書くだけで:

final users = await supabase
  .from('profiles')          // ← 自社DBスキーマ名を学習
  .select('id, display_name, avatar_url')  // ← 自社で使うカラム名
  .eq('is_active', true)     // ← 自社の論理削除パターン
  .order('created_at');      // ← 自社の標準ソート
```

## 自分株式会社での活用戦略

```
1. GitHub Organization 学習設定:
   → my_web_app リポジトリを学習対象に追加
   → Supabaseスキーマ・Flutter設計パターンを学習

2. AI_FALLBACK_RUNBOOK での位置づけ:
   → Claude Code quota超過時のフォールバック先 (Primary: Gemini Code Assist)
   → Flutter/Firebase系タスク: Gemini Code Assist が最適 (Google製)
   → 長文リファクタリング: Gemini 2.0 Flash の大コンテキストを活用

3. 12インスタンス fleet での補完:
   → VSCode版インスタンス: Gemini Code Assist 有効化推奨
   → inline補完の 60% をGeminiに委譲 → Claude quotaを設計判断に集中
```

## 自分株式会社 AI 大学での位置づけ

- **カテゴリ**: 開発ツール / Googleエコシステム / AI駆動開発学科
- **関連プロバイダー**: Claude Code / GitHub Copilot / Cursor / AI_FALLBACK_RUNBOOK
- **実用的示唆**: Domain-Specific AI は 自分株式会社の「inject-rules.txt毎ターン注入」と同じ思想
  → AIに文脈を「毎回提供」するより「一度学習」させる方がスケーラブル
$$,
  'https://cloud.google.com/gemini/docs/codeassist/overview',
  '2026-01-01',
  97
)
ON CONFLICT (provider, category) DO NOTHING;
