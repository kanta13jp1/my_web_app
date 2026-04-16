---
title: "【実践】Claude Code Schedule でサポート対応・競合モニタリングを完全自動化する手順"
tags: Claude,個人開発,Flutter,Supabase,自動化
published: false
---

# 【実践】Claude Code Schedule でサポート対応を自動化する具体的な手順

## タイトル案
1. 【実践】Claude Code Schedule でサポート対応を自動化する具体的な手順
2. Claude Code Schedule + Supabase Edge Functions で CS を全自動化した
3. 個人開発のCS対応をゼロコストで自動化する方法 (Claude Code Schedule)

## 投稿先
- [x] Qiita (実用・手順書)

## 本文

### はじめに

Claude Code の Schedule 機能を使って、Flutter Web + Supabase アプリのサポート対応を自動化しました。この記事では、設定手順を具体的に説明します。

### 前提条件

- Claude Pro プラン以上
- GitHub リポジトリ
- Supabase プロジェクト (Edge Functions 利用可能)

### Step 1: Supabase Edge Function を作る

まず、チケット取得 API を作ります。

```typescript
// supabase/functions/get-support-tickets/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  // 認証チェック
  const authHeader = req.headers.get("Authorization");
  // ... (Bearer token 検証)

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 未返信チケットを取得
  const { data: tickets } = await supabase
    .from("support_requests")
    .select("*")
    .eq("status", "new")
    .order("created_at", { ascending: true });

  // FAQ 一覧を取得
  const { data: faq } = await supabase
    .from("faq")
    .select("*");

  return new Response(
    JSON.stringify({ tickets: tickets ?? [], faq: faq ?? [] }),
    { headers: { "Content-Type": "application/json" } },
  );
});
```

### Step 2: 返信 API を作る

```typescript
// supabase/functions/reply-support-request/index.ts
// POST { id, reply, newStatus } or { id, escalate: true }
```

### Step 3: CLAUDE.md にタスクを定義する

```markdown
### Task: cs-check (毎時 実行)

#### Step 1: 未返信チケットを取得
WebFetch で GET /functions/v1/get-support-tickets を叩く。

#### Step 2: 各チケットを判断
- FAQ で答えられる → 返信文を生成 → POST /reply-support-request
- バグの可能性 → ソースを読んで修正 → git commit → push → 返信
- 判断困難 → エスカレーション
```

### Step 4: Schedule を設定する

Claude Code のターミナルで:
```
このリポジトリで毎時サポートチケットを確認して対応するスケジュールを作って
```

### 実行ログの確認

`schedule_task_runs` テーブルを作り、各実行の結果を記録します:

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

Flutter の管理者ダッシュボードで ScheduleTaskMonitorCard を使って確認できます。

### まとめ

- Supabase Edge Function で薄い API を作る
- CLAUDE.md にタスク定義を書く
- Schedule を設定する

この3ステップで CS 対応が自動化できます。

### 参考リンク

- サービス: https://my-web-app-b67f4.web.app/
- GitHub: https://github.com/kanta13jp1/my_web_app

#ClaudeCode #Supabase #Flutter #自動化
