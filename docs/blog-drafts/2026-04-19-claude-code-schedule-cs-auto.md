---
title: "Claude Code Scheduleで個人SaaSのCS対応を完全自動化する — FAQ返信・バグ修正・エスカレーション"
tags: Claude,AI,個人開発,SaaS,buildinpublic
published: true
---

# Claude Code Scheduleで個人SaaSのCS対応を完全自動化する

## 課題: 個人開発SaaSのCSボトルネック

個人開発SaaSを運営していると、ユーザーからの問い合わせへの対応が開発時間を圧迫する。

- 「ログインできない」
- 「データが消えた」
- 「この機能は使えますか?」

典型的なパターンは限られているにもかかわらず、1つ1つ手動で返信するのは非効率だ。

## 解決策: Claude Code Schedule + cs-check タスク

Claude Code CLI の Schedule 機能を使い、毎時自動でCS対応を実行する:

```yaml
# .claude/schedule.yaml
tasks:
  - name: cs-check
    cron: "0 * * * *"  # 毎時00分
    prompt: |
      Task: cs-check
      未返信チケットを取得し、FAQ返信・バグ修正・エスカレーションを自動処理する
```

## 3ステップの自動CS処理

### Step 1: 未返信チケットを取得

```typescript
// get-support-tickets Edge Function
const tickets = await supabase
  .from('support_tickets')
  .select('id, title, body, status, user_id')
  .eq('status', 'open')
  .is('replied_at', null)
  .order('created_at');
```

### Step 2: 3ケースに分類して対応

```text
ケース A: FAQ で答えられる
  → FAQ 一覧と照合 → 自動返信

ケース B: バグの可能性がある
  → ソースを読んで原因特定 → 軽微なら修正してコミット

ケース C: 返金・課金・判断困難
  → エスカレーション記録のみ
```

実際の判断ロジック:

```typescript
// reply-support-request Edge Function
async function processTicket(ticket: Ticket, faq: FAQ[]) {
  const similar = faq.find(f =>
    similarity(ticket.title, f.question) > 0.7
  );

  if (similar) {
    // ケースA: FAQ返信
    return await replyWithFaq(ticket.id, similar.answer);
  }

  const bugKeywords = ['動かない', 'エラー', 'できない', 'バグ', 'error'];
  if (bugKeywords.some(k => ticket.body.includes(k))) {
    // ケースB: バグ調査 (Claudeが判断)
    return { action: 'investigate_bug', ticket };
  }

  // ケースC: エスカレーション
  return { action: 'escalate', ticket };
}
```

### Step 3: バグケースの自動修正

Claude がバグを特定したら自動修正してコミット:

```bash
# flutter analyze で確認
flutter analyze lib/
# 0エラー確認後コミット
git add -p
git commit -m "fix: <バグ内容>"
git push origin main
# 返信文に「修正しました」と記載
```

## cs-notes で記録管理

対応内容は `docs/cs-notes/` に自動記録される:

```markdown
# CS チェック 2026-04-19 10:00

## 対応済み (FAQ返信)
- 「パスワードリセットができない」→ メール送信手順を案内

## 対応済み (バグ修正)
- 「ホーム画面がロードされない」→ null check修正 commit: abc1234

## エスカレーション (要人間対応)
- 「課金を取り消してほしい」→ 返金フロー必要
```

## インフラヘルスチェックも並行実施

CS チェック内でエンドポイント監視も行う:

```typescript
const endpoints = [
  'https://smmkxxavexumewbfaqpy.supabase.co/functions/v1/get-home-dashboard',
  'https://my-web-app-b67f4.web.app/',
];

for (const url of endpoints) {
  const res = await fetch(url, { signal: AbortSignal.timeout(10000) });
  if (!res.ok) {
    // インフラ異常をcs-notesに記録
    appendToNote(`## インフラ異常\n- ${url}: ${res.status}`);
  }
}
```

## 効果

| 指標 | Before | After |
|------|--------|-------|
| 返信平均時間 | 24時間 | 1時間 |
| 手動対応割合 | 100% | ~20% |
| バグ検出→修正時間 | 手動 | 自動 (数分) |
| CS対応のストレス | 高 | 低 |

個人開発では**CSの自動化**がユーザー体験と開発生産性の両方を上げる最重要投資の一つだ。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Claude #AI #buildinpublic #個人開発 #SaaS
