---
title: "Supabase Edge FunctionのDeno import管理 — deno.json・バージョン固定・lint 0エラー維持"
tags: Supabase,Deno,TypeScript,個人開発,buildinpublic
published: true
---

# Supabase Edge FunctionのDeno import管理

## Deno の import は URL ベース

Node.js と違い Deno は npm install なし。import は URL を直接書く:

```typescript
// npm 方式 (使えない)
import { createClient } from 'supabase';

// Deno 方式 (ESM URL)
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
```

## バージョン固定が重要

```typescript
// ❌ バージョン未固定 → CI が突然壊れる
import { Hono } from 'https://deno.land/x/hono/mod.ts';

// ✅ バージョン固定
import { Hono } from 'https://deno.land/x/hono@v4.7.0/mod.ts';
```

Deno.land の `@latest` タグは動的に変わる。固定しないと朝は動き夜は壊れる。

## deno.json でエイリアス管理

`supabase/functions/deno.json` を使うと import を一元管理できる:

```json
{
  "imports": {
    "@supabase/supabase-js": "https://esm.sh/@supabase/supabase-js@2.49.4",
    "hono": "https://deno.land/x/hono@v4.7.0/mod.ts",
    "hono/cors": "https://deno.land/x/hono@v4.7.0/middleware/cors/index.ts"
  }
}
```

各 EF では:

```typescript
// エイリアスを使う (URLを書かない)
import { createClient } from '@supabase/supabase-js';
import { Hono } from 'hono';
```

バージョンアップは `deno.json` の1箇所だけ変更すればOK。

## hub パターンでの共通モジュール

50本 EF ハードキャップに対応するため、action dispatch パターンの共通ロジックを整理する:

```typescript
// supabase/functions/_shared/supabase.ts
import { createClient } from '@supabase/supabase-js';

export function getSupabaseClient(req: Request) {
  const authHeader = req.headers.get('Authorization');
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader! } } }
  );
}

export function getAdminClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );
}
```

## deno lint 0エラー維持

`deno lint` は CI で自動チェックされる。よくある違反:

```typescript
// ❌ prefer-const
let x = 42;  // 再代入なし → const にする

// ✅
const x = 42;

// ❌ no-explicit-any
function foo(x: any) {}

// ✅
function foo(x: unknown) {}
// or
function foo<T>(x: T) {}
```

Edge Function 変更後は必ず:

```bash
deno lint supabase/functions/
```

## import_map.json vs deno.json

古いプロジェクトでは `import_map.json` を使っているかもしれないが、
Deno 1.30+ では `deno.json` の `imports` フィールドが推奨:

```bash
# 移行
mv supabase/functions/import_map.json supabase/functions/deno.json
# deno.json に { "imports": {...} } をラップして完了
```

## まとめ

| 管理ポイント | 対策 |
|------------|------|
| バージョン固定 | URL に `@x.y.z` を必ず書く |
| エイリアス管理 | `deno.json` の `imports` で一元管理 |
| 共通ロジック | `_shared/` に切り出す |
| lint チェック | EF変更後は `deno lint` 必須 |

---
自分株式会社: https://my-web-app-b67f4.web.app/
#Supabase #Deno #TypeScript #buildinpublic #個人開発
