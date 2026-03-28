# Claude Code Schedule で CS・バグ修正・競合モニタリングを完全自動化した話

## タイトル案
1. Claude Code Schedule で CS・バグ修正・競合モニタリングを完全自動化した話
2. PCもサーバーも不要: Claude Code Schedule で9つの定期タスクを無料自動化
3. Flutter Web + Supabase アプリの運用を Claude Code Schedule で完全自動化する方法

## 投稿先候補
- [x] Zenn (技術実装メイン)
- [ ] Qiita (実用Tips)
- [ ] dev.to (英語版)
- [ ] note (エッセイ)

## 本文下書き

### はじめに

個人開発アプリ「自分株式会社」の運用を Claude Code Schedule で完全自動化した。

CS対応、バグ修正、競合モニタリング、日次レポート、X投稿、PRレビュー、インフラ監視、脆弱性チェック、ブログ下書き生成。合計9つのタスクを、PCを起動せずに定期実行している。

### 技術スタック

- **フロントエンド**: Flutter Web (Dart)
- **バックエンド**: Supabase (PostgreSQL + Edge Functions / Deno)
- **ホスティング**: Firebase Hosting
- **CI/CD**: GitHub Actions (push to main → 自動デプロイ)
- **自動化**: Claude Code Schedule

### 実装のポイント

#### 1. CLAUDE.md にタスク定義を書くだけ

```markdown
### Task: cs-check (毎時 実行)
1. WebFetch で GET /functions/v1/get-support-tickets
2. FAQ で答えられる → 返信
3. バグの可能性 → ソースを読んで修正 → git commit → push
4. 判断困難 → エスカレーション
```

#### 2. Edge Function で薄い API を用意

```typescript
// get-support-tickets: 未返信チケット + FAQ を返す
// reply-support-request: 返信 or エスカレーション
// health-check: DB接続性・テーブル可用性チェック
// check-competitor-updates: 競合21社 HEAD リクエスト
```

#### 3. 実行ログを schedule_task_runs テーブルに記録

```sql
CREATE TABLE schedule_task_runs (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  task_id text NOT NULL,
  status text NOT NULL DEFAULT 'running',
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  summary text
);
```

管理者ダッシュボードの ScheduleTaskMonitorCard で実行状況を確認できる。

### 9つの自動化タスク

| タスク | 頻度 | やること |
|--------|------|----------|
| daily-report | 毎日 09:00 | メトリクス取得 → レポート生成 → X投稿 → 競合チェック |
| cs-check | 毎時 | チケット確認 → FAQ返信 / バグ修正 / エスカレーション |
| weekly-sns-draft | 毎週月曜 | 週次実績サマリー → SNS投稿ドラフト |
| daily-development | 毎日 10:00 | ロードマップに沿って開発を推進 |
| pr-auto-review | 3時間毎 | open PR のコードレビュー |
| competitor-monitoring | 毎日 07:00 | 競合21社のWebサイト・ニュースチェック |
| infra-health-check | 毎時 30分 | DB・Firebase Hosting の可用性確認 |
| dependency-audit | 毎週月曜 | Flutter/Deno 依存パッケージの脆弱性チェック |
| blog-draft | 毎日 08:00 | 技術ブログ下書き自動生成 |

### 詰まったポイント

1. **Schedule サンドボックスの制約**: SSH不可、DB直接接続不可。すべて WebFetch (HTTP) 経由で操作する必要がある → Edge Function を薄い API として用意することで解決

2. **同一周期の制約**: 同じ cron 式は1つしか設定できない → タスクを統合するか、異なる分オフセットで対応

3. **RLS との戦い**: Schedule からの書き込みは service_role で行うため、RLS ポリシーを service_role 用に設定する必要がある

### まとめ

Claude Code Schedule を使えば:
- PC不要、サーバー不要、API代金不要
- CLAUDE.md を書き換えるだけで動作を変更
- CS対応、バグ修正、モニタリング、レポート、ブログ下書きまで自動化

Pro プラン以上を契約しているなら追加費用ゼロで使える。

---
URL: https://my-web-app-b67f4.web.app/
GitHub: https://github.com/kanta13jp1/my_web_app
#FlutterWeb #Supabase #ClaudeCode #buildinpublic
