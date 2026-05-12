---
title: "インディー SaaS のリテンション戦略 — チャーン分析・メール自動化・習慣化 UX の実装"
tags: flutter,dart,個人開発,AI
published: true
---

# インディー SaaS のリテンション戦略 — チャーン分析・メール自動化・習慣化 UX の実装

「ユーザーが増えているのに MRR が伸びない」「トライアル後に消えてしまう」——インディー SaaS でよく見られるこの問題は、**リテンション（継続率）**の低さが原因であることがほとんどです。本記事では、Supabase・Resend・Flutter を組み合わせてリテンションを改善する実践的な手法を解説します。

## チャーン予測シグナルの定義

チャーンは突然起きるのではなく、事前にシグナルが出ています。代表的な予測シグナルは以下のとおりです。

| シグナル | 閾値（例） |
|--------|---------|
| ログイン頻度低下 | 過去 7 日間のログイン回数 < 1 |
| コア機能の利用停止 | 30 日間でコア機能を 0 回使用 |
| サポートチケットの増加 | 直近 14 日で 3 件以上 |
| プロフィール未完了 | 登録 3 日後にプロフィール完了率 < 50% |

これらを Supabase の `user_events` テーブルと `pg_cron` で定期的に集計し、チャーンリスクスコアを計算します。

## Supabase + pg_cron でチャーンリスクユーザーを自動検出

```sql
-- churn_risk ビュー: 過去7日間ログインなし のユーザーを抽出
create or replace view churn_risk_users as
select
  u.id,
  u.email,
  u.raw_user_meta_data->>'full_name' as full_name,
  max(e.created_at) as last_login,
  now() - max(e.created_at) as days_since_login
from auth.users u
left join user_events e
  on u.id = e.user_id and e.event_type = 'login'
group by u.id, u.email, u.raw_user_meta_data
having now() - max(e.created_at) > interval '7 days'
  or max(e.created_at) is null;

-- pg_cron: 毎日 UTC 1:00 にリスクユーザーを churn_alerts テーブルに書き出す
select cron.schedule(
  'churn-risk-scan',
  '0 1 * * *',
  $$
  insert into churn_alerts (user_id, email, days_since_login, alerted_at)
  select id, email, days_since_login, now()
  from churn_risk_users
  where days_since_login > interval '7 days'
  on conflict (user_id) do update
    set days_since_login = excluded.days_since_login,
        alerted_at = excluded.alerted_at;
  $$
);
```

## Resend API でトリガーメールを送信する

`churn_alerts` テーブルへの INSERT を Supabase Database Webhook で捕捉し、Edge Function 経由で Resend API を呼び出してリアクティベーションメールを送ります。

```typescript
// supabase/functions/send-reactivation-email/index.ts
import { Resend } from "npm:resend@3";

const resend = new Resend(Deno.env.get("RESEND_API_KEY")!);

Deno.serve(async (req) => {
  const { record } = await req.json(); // Database Webhook payload

  const { error } = await resend.emails.send({
    from: "support@jibun-kabushiki.com",
    to: record.email,
    subject: "最近のご利用状況のご確認",
    html: `
      <p>${record.full_name ?? "ご利用中の方"} さん、こんにちは。</p>
      <p>最近 <strong>${Math.floor(record.days_since_login)} 日間</strong>
         ご利用がないことに気づきました。</p>
      <p>新機能「AIデイリー判定」が追加されましたので、ぜひお試しください。</p>
      <a href="https://my-web-app-b67f4.web.app/">アプリを開く</a>
    `,
  });

  return new Response(
    JSON.stringify({ ok: !error }),
    { headers: { "Content-Type": "application/json" } }
  );
});
```

メール送信後は `churn_alerts.email_sent_at` を更新し、重複送信を防いでください。

## 習慣化 UX — ストリーク・進捗バー・マイルストーン通知

ユーザーがアプリを毎日使う習慣を作るには、**小さな達成感**を繰り返し提供することが重要です。

### ストリーク（連続利用日数）

```dart
// Flutter 側: ストリーク表示ウィジェット
class StreakBadge extends StatelessWidget {
  final int streakDays;

  const StreakBadge({super.key, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.local_fire_department, color: Colors.orange),
        const SizedBox(width: 4),
        Text(
          '$streakDays 日連続',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}
```

### 進捗バー

目標に対する進捗をパーセンテージで可視化します。Supabase の `user_stats` テーブルからデータを取得し、`LinearProgressIndicator` で表示するシンプルな実装が効果的です。

### マイルストーン通知

「30日連続ログイン」「タスク100件完了」などのマイルストーンに達したタイミングで、Edge Function からプッシュ通知または in-app 通知を送ります。

## NPS 調査を in-app で実装する

NPS（Net Promoter Score）は「このアプリを友人に勧めますか？（0〜10）」の 1 問で測定できます。表示タイミングは「30 日使用後」または「タスク 10 件完了後」が効果的です。

```dart
Future<void> _maybeShowNps(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyShown = prefs.getBool('nps_shown') ?? false;
  final taskCount = await _getTaskCount(); // Supabase から取得

  if (!alreadyShown && taskCount >= 10) {
    await prefs.setBool('nps_shown', true);
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        builder: (_) => const NpsDialog(),
      );
    }
  }
}
```

回答は Supabase の `nps_responses` テーブルに保存し、スコアが 6 以下なら自動でサポートチームに Slack 通知を送る設計にすると、改善につながる声を素早くキャッチできます。

## まとめ

1. **チャーンシグナル**を定量化して `pg_cron` で自動検出する
2. **Resend** でトリガーメールを送り、7 日未ログインユーザーを取り戻す
3. **ストリーク・進捗バー・マイルストーン**で毎日の利用習慣を形成する
4. **NPS を in-app で実装**してネガティブフィードバックを早期キャッチ

リテンションは新規獲得の 5 倍安く MRR を伸ばせます。まず計測から始めましょう。次回は Dart の並行処理完全ガイドです。
