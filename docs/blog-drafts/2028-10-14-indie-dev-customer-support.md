---
title: "個人開発のカスタマーサポート自動化 — FAQ Bot・チケット管理・エスカレーション"
tags: AI,個人開発,automation,buildinpublic
published: true
---

# 個人開発のカスタマーサポート自動化 — FAQ Bot・チケット管理・エスカレーション

1人でサポートを回すには自動化が必須。最小コスト構成を解説する。

## アーキテクチャ

```
ユーザー → 問い合わせフォーム → Supabase (support_tickets テーブル)
Supabase → GHA cs-check (1時間毎) → Claude API (FAQ 自動返信)
Claude 解決不可 → Slack DM (エスカレーション) → 手動対応
```

## FAQ 自動返信の実装

```typescript
// supabase/functions/get-support-tickets の応答から
// cs-check GHA が Claude に問い合わせ
const prompt = `
以下はユーザーからの問い合わせです。
FAQ から回答できる場合は返信文を生成してください。
解決できない場合は "ESCALATE" と返してください。

問い合わせ: ${ticket.message}

FAQ:
- ログインできない → パスワードリセットはこちら: [URL]
- 料金について → 月額プランは [URL] を参照
- データのエクスポート → 設定 > データ管理 > エクスポート
`;

const response = await anthropic.messages.create({
  model: 'claude-haiku-4-5-20251001',
  max_tokens: 500,
  messages: [{ role: 'user', content: prompt }],
});
```

## チケット管理スキーマ

```sql
CREATE TABLE support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  message TEXT NOT NULL,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'auto_replied', 'escalated', 'resolved')),
  auto_reply TEXT,
  replied_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS: ユーザーは自分のチケットのみ参照可
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own tickets" ON support_tickets
  FOR ALL USING (auth.uid() = user_id);
```

## エスカレーション通知 (Slack)

```typescript
async function escalate(ticket: SupportTicket): Promise<void> {
  await fetch(Deno.env.get('SLACK_WEBHOOK')!, {
    method: 'POST',
    body: JSON.stringify({
      text: `🚨 エスカレーション: ${ticket.id.slice(0, 8)}\n${ticket.message.slice(0, 200)}`,
    }),
  });
  await supabase.from('support_tickets')
    .update({ status: 'escalated' })
    .eq('id', ticket.id);
}
```

## まとめ

```
自動返信率目標  → 70% (残り30%は手動)
応答時間        → GHA 1時間毎 → 最大1h以内に自動返信
Claude モデル   → Haiku (コスト最小・FAQ返信に十分)
エスカレーション → Slack DM (緊急度高) or メール (翌日対応可)
```

FAQ Bot が 7 割を処理すれば、手動対応は週数件に収まる。
