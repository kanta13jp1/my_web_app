---
title: "Deno vs Node.js — Edge Functions で使うならどちらか【2026年版】"
tags: Deno,個人開発,webdev,saas
published: true
---

# Deno vs Node.js — Edge Functions で使うならどちらか【2026年版】

## 「Edge Functions は Deno と Node.js どちらが向いているか」

Supabase Edge Functions は Deno ランタイムを採用している。一方、Vercel Edge Functions / Cloudflare Workers は Node.js 互換の V8 isolates を使う。

どちらを選ぶべきか。自分株式会社で Deno を選んだ経緯と、実際に感じたトレードオフを整理する。

---

## 主要プラットフォームのランタイム

| プラットフォーム | ランタイム | Node 互換 |
|----------------|-----------|----------|
| Supabase Edge Functions | **Deno** | 部分的 (npm: スキーム) |
| Vercel Edge Functions | V8 isolates (Node 互換) | ほぼ完全 |
| Cloudflare Workers | V8 isolates (Workerd) | ほぼ完全 |
| AWS Lambda | Node.js 20/22 | 完全 |
| Google Cloud Functions | Node.js 20/22 | 完全 |

---

## Deno の強みと弱み

### 強み

**1. セキュリティファースト設計**

```bash
# パーミッション制御が明示的
deno run --allow-net --allow-env index.ts
# ファイルアクセスなし → --allow-read 不要
```

ファイル読み書き・ネットワーク・環境変数へのアクセスは明示的に許可が必要。Edge Functions として動かす場合はこれが自動制御されるため、セキュリティ上のリスクが低い。

**2. TypeScript ネイティブ**

```typescript
// tsconfig.json 不要、そのまま動く
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

serve(async (req: Request): Promise<Response> => {
  const body = await req.json();
  return new Response(JSON.stringify({ ok: true }));
});
```

Node.js では `ts-node` や `tsx` が必要な TypeScript を、Deno はビルドステップなしで実行できる。

**3. URL imports によるゼロ依存インストール**

```typescript
// package.json も node_modules も不要
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import Anthropic from "https://esm.sh/@anthropic-ai/sdk@0.39.0";
```

`npm install` が不要。コールドスタート時のファイル読み込みが速い。

**4. Web 標準 API**

`fetch`, `Request`, `Response`, `ReadableStream`, `WebSocket` などが標準搭載。Node の `http` モジュールより直感的。

### 弱み

**1. npm パッケージとの相性**

```typescript
// npm: スキームで大半は動くが...
import sharp from "npm:sharp"; // ネイティブバイナリ → 動かない場合あり
import puppeteer from "npm:puppeteer"; // ブラウザ依存 → 動かない
```

ネイティブバイナリを含む npm パッケージは Deno では動作しないことがある。画像処理や PDF 生成など、バイナリ依存が強い処理は Node.js が有利。

**2. エコシステムの小ささ**

Stack Overflow の質問数・GitHub Issues・Qiita 記事数はどれも Node.js より少ない。詰まったときに情報が少ない。

**3. ローカル開発の学習コスト**

```bash
# Deno でのローカル EF 開発
supabase functions serve ai-assistant --env-file .env.local

# Node での Lambda ローカル開発
sam local start-api
```

Supabase CLI で抽象化されているが、Deno 固有の挙動 (URL imports のキャッシュ、パーミッション) を理解する必要がある。

---

## Node.js の強みと弱み

### 強み

**1. npm エコシステムの豊富さ**

2 million+ パッケージ。大抵のことは既存ライブラリで解決できる。

**2. 情報量**

ドキュメント・チュートリアル・Stack Overflow の回答が圧倒的に多い。

**3. ネイティブバイナリ対応**

`sharp` (画像処理)、`pdfkit`、`better-sqlite3` など、ネイティブモジュールが動く。

### 弱み

**1. TypeScript は別途設定が必要**

```json
// tsconfig.json, ts-node, esbuild など設定が必要
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs"
  }
}
```

**2. セキュリティデフォルトが緩い**

ファイルシステム・ネットワーク・環境変数に制限なくアクセスできる。依存パッケージのサプライチェーン攻撃リスクが高い。

**3. コールドスタートが遅い**

`node_modules` のファイル数が多いと、Lambda / Cloud Functions のコールドスタートが数秒に達することがある。

---

## 実際に Deno を選んだ理由

自分株式会社が Supabase (Deno) を選んだ決め手:

1. **Supabase を使うなら Deno 一択** — プラットフォームとのインテグレーションが最も深い
2. **TypeScript ネイティブ** — 設定なしで型安全に書ける
3. **npm 依存が少ない用途** — AI API 呼び出し・DB 操作・JSON 変換がメインで、バイナリ依存なし
4. **セキュリティ要件** — マルチユーザー SaaS として、EF レベルでの権限制御が欲しかった

---

## Deno × Supabase のパターン集

### 基本構造

```typescript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SERVICE_ROLE_KEY")!,
  );

  const body = await req.json();
  // ... 処理 ...

  return new Response(JSON.stringify({ result: "ok" }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
```

### 複数アクションを1 EF にまとめる (Hub パターン)

```typescript
// action ルーティング
const action = body.action as string;
switch (action) {
  case "support.list":
    return await handleSupportList(supabase);
  case "support.reply":
    return await handleSupportReply(supabase, body);
  default:
    return new Response(JSON.stringify({ error: "Unknown action" }), {
      status: 400, headers: corsHeaders,
    });
}
```

自分株式会社では 30+ の個別 EF を `tools-hub` 1本に統合。EF の上限 (50本) を節約できる。

### エラーハンドリング

```typescript
try {
  const result = await riskyOperation();
  return json({ success: true, data: result });
} catch (err) {
  const message = err instanceof Error ? err.message : String(err);
  console.error("[EF Error]", message);
  return new Response(JSON.stringify({ error: message }), {
    status: 500, headers: corsHeaders,
  });
}
```

---

## 選択基準まとめ

| 条件 | 推奨 |
|------|------|
| Supabase を使っている | **Deno** (一択) |
| Vercel / Cloudflare を使っている | **Node 互換** (V8 isolates) |
| npm のネイティブモジュールが必要 | **Node.js** (Lambda/Cloud Functions) |
| TypeScript をゼロコンフィグで使いたい | **Deno** |
| 情報量・エコシステム重視 | **Node.js** |
| セキュリティ・パーミッション制御重視 | **Deno** |

プラットフォームが決まっていれば、ランタイムは自動的に決まることが多い。「Deno か Node か」ではなく「Supabase か Vercel か Cloudflare か」を先に決める方が本質的な選択だ。

---

## まとめ

2026年時点での結論:

- **Supabase を選ぶなら Deno を受け入れる** — 逆らうと不便なだけ
- **Deno の弱点はニッチなバイナリ依存パッケージのみ** — AI/DB/HTTP の用途なら問題なし
- **TypeScript ネイティブ・URL imports・セキュリティ** は Edge Functions 用途に向いている
- Node.js が必要になるのは「npm の特定パッケージが必要」なときだけ

Supabase Edge Functions で AI バックエンドを作るなら、Deno は十分実用的な選択肢だ。

---

## 関連記事

- [Supabase Edge Functions × AI コスト内訳](./2026-08-22-supabase-edge-functions-ai-cost.md)
- [Flutter Web × AI 統合 2026](./2026-08-29-flutter-web-ai-integration-2026.md)
- [litellm で複数AI APIを統合管理](./2026-08-01-litellm-unified-ai-gateway.md)

---

*自分株式会社 — 21社競合のベストを1つに統合するライフマネジメントアプリ*  
*本番: https://my-web-app-b67f4.web.app/*
