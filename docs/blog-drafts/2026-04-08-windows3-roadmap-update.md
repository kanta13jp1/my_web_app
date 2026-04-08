---
title: Flutter Web × Supabase を4インスタンス並列開発で進化させる運用ノウハウ
emoji: 🔀
type: tech
topics: [flutter, supabase, claudecode, cicd, paralleldev]
published: false
---

# Flutter Web × Supabase を4インスタンス並列開発で進化させる運用ノウハウ

## はじめに

自分株式会社 (https://my-web-app-b67f4.web.app/) は Flutter Web + Supabase で構築した AI 統合ライフマネジメントアプリです。
Notion・Evernote・MoneyForward・X など21の競合 SaaS を1つに統合するという野心的なプロダクトを **1人** で開発しています。

開発速度を最大化するために、**4つの Claude Code インスタンスを同時並行で実行**する体制を組んでいます。
この記事では、その運用ノウハウと競合ゼロを維持するための仕組みを解説します。

## 4インスタンス並列開発の役割分担

```
VSCode 版        → lib/ フロントエンド実装 (Dart/Flutter)
Web 版           → supabase/functions/ Edge Functions (Deno)
Windows アプリ版 → docs/ ドキュメント・マイグレーション
PowerShell 版    → 全体管理・git 統括
```

それぞれが **担当ディレクトリ外を変更しない** というルールを守ることで、マージ競合を最小化しています。

## 競合防止の鉄則: git pull --rebase 先行実行

各インスタンスが作業を始める前に必ず実行するコマンド:

```bash
git pull --rebase origin main
```

これだけで、4インスタンスが同時にプッシュしても失敗がほぼゼロになります。

### 競合が起きたときの対処

```bash
# unstaged changes がある場合
git stash
git pull --rebase origin main
git stash pop

# コンフリクトが発生した場合 (upstream 優先)
git restore --staged <file>
git restore <file>
```

## flutter analyze 0件を維持する仕組み

並列開発の最大のリスクは **lint エラーの混入** です。
各インスタンスが変更後に必ず `flutter analyze --no-pub` を実行し、0件を確認してからプッシュします。

```bash
flutter analyze --no-pub 2>&1 | tail -5
# 期待出力: No issues found!
```

本日 (2026-04-08) も 314秒フルスキャンで **No issues found** を確認しました。

## Claude Code Schedule による自動化ループ

4インスタンスの他に、Claude Code Schedule が以下のタスクを自動実行しています:

| タスク | 頻度 | 役割 |
|--------|------|------|
| `cs-check` | 毎時 | CS 対応・バグ自動修正・GitHub Issue 修復 |
| `daily-report` | 毎朝 09:00 JST | 日次レポート生成・X 自動投稿 |
| `blog-draft` | 毎朝 08:00 JST | 技術ブログ下書き生成 |
| `weekly-sns-draft` | 毎週月曜 | 週次 SNS ドラフト生成 |

## 開発実績の記録方法

実装した機能は必ず `supabase/migrations/` に seed ファイルとして記録します:

```sql
INSERT INTO development_achievements (title, description, completed_at)
VALUES (
  '機能タイトル',
  '実装の詳細説明',
  '2026-04-08'
) ON CONFLICT DO NOTHING;
```

この記録がホーム画面の **開発実績カード** にリアルタイム表示されます。

## 今後の展望

- Bonsai-8B (1.15GB の軽量 LLM) の台頭を見据え、Edge Functions をオフライン対応可能な設計へ移行
- awesome-design-md-jp の note/freee/SmartHR デザインシステムを適用し UI を全面刷新
- ギター録音 → X 自動投稿パイプラインでバイラル係数 > 1 を目指す

## まとめ

4インスタンス並列開発は「担当ディレクトリの分離」と「git pull --rebase 先行実行」の2つのルールで成立します。
flutter analyze 0件を維持しながら、毎日コミットを積み上げていく体制が整っています。

---

URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #ClaudeCode #buildinpublic
