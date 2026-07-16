---
title: "その anon key、実質公開ですよ: Supabase Edge Function の publicActions に空いていた認可の穴を塞いだ話"
tags: Supabase,セキュリティ,Deno,buildinpublic,個人開発
published: true
---

# その anon key、実質公開ですよ: Supabase Edge Function の publicActions に空いていた認可の穴を塞いだ話

## はじめに

個人開発している Flutter Web + Supabase の SaaS「自分株式会社」で、Supabase Edge Function (Deno) の認可設計に穴が空いていたのを見つけて塞いだ。ブログ自動投稿・X (Twitter) 自動投稿・外部 API バックフィルといった **書き込み系の処理が、認証なしで誰でも叩ける状態**になっていた話だ。

結論を先に書くと、原因は「Web アプリに同梱している Supabase の anon key を、まるで秘密の鍵かのように扱っていた」ことだった。同じ轍を踏まないよう、見つけ方・直し方・そして**副作用ゼロで本番検証する方法**まで含めて残しておく。

## 何が起きていたか

Edge Function `schedule-hub` は、1 本の関数が `action` フィールドで処理を振り分ける「ハブ」型の設計になっている。その入口に、認証を免除する `publicActions` という配列があった。

```typescript
const publicActions = [
  "health.check",
  "blog.recent_posted",   // 公開読み取り — これは OK
  "blog.auto_publish",    // ← オーナーの Qiita/dev.to トークンで記事投稿
  "blog.create",          // ← DB に system 権限で行を insert
  "blog.backfill_from_apis", // ← 外部 API fetch + DB insert
  "x.post_with_media",    // ← オーナーの X アカウントで任意投稿
  // ...
];

const serviceRoleRequest = isServiceRoleRequest(req);
let userId: string | null = null;
if (!publicActions.includes(action)) {
  if (!serviceRoleRequest) {
    userId = await getUserId(req);
    if (!userId) return json({ error: "Unauthorized" }, 401);
  }
}
```

読み取り専用の `health.check` や `blog.recent_posted` が public なのは意図通りだ。問題は、そこに**書き込み系の 4 action が紛れ込んでいた**こと。

- `blog.auto_publish` — サーバー側の `QIITA_ACCESS_TOKEN` / `DEVTO_API_KEY` を使って、**任意のタイトル・本文で記事を投稿できる**
- `x.post_with_media` — サーバー側の X API 資格情報で、**任意のツイートを投稿できる**
- `blog.create` / `blog.backfill_from_apis` — `hub_data` テーブルに `user_id="system"` で行を書き込める

これらが `publicActions` に入っているということは、`getUserId()` も `isServiceRoleRequest()` も通らずにハンドラへ到達する、ということだ。

## なぜ「誰でも」叩けるのか — anon key の誤解

「でも Edge Function を呼ぶには `Authorization` ヘッダに Supabase の anon key が必要でしょ?」と思うかもしれない。まさにそこが落とし穴だった。

Supabase の anon key は、**フロントエンドに埋め込んで配布する前提の公開鍵**だ。自分の Flutter Web アプリも、ビルド成果物 `main.dart.js` の中に anon key を平文で持っている。つまり、アプリを開けば誰でも DevTools やソース閲覧で anon key を取り出せる。

```dart
// lib/main.dart — ビルド成果物に平文で載る
await Supabase.initialize(
  url: 'https://<project>.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiI...', // ← 秘密ではない
);
```

Edge Function のプラットフォーム JWT 検証は、この anon key で普通に通る。だから「anon key が要る = 認証されている」は**完全な誤り**で、実態は「Web アプリを開いた第三者なら誰でも、オーナーの資格情報で投稿を実行できる」状態だった。秘密の鍵で守られているのは `SERVICE_ROLE_KEY`(サーバー間通信専用・絶対にクライアントへ出さない)だけだ。

## 直し方: 認可レベルを純ロジックに切り出す

修正方針はシンプルで、**書き込み系 action を `publicActions` から外し、`SERVICE_ROLE_KEY` 必須ゲートの配下へ移す**。ただしインラインの配列を書き換えるだけだと、また別の action がしれっと紛れ込む。そこで action ごとの必要認可レベルを判定する純ロジックを別モジュールに切り出した。Deno API に依存しないので、そのまま VM 単体テストできる。

```typescript
// action_auth.ts — 認可レベルを 3 段階で集約
export type ActionAuthLevel = "public" | "service_role" | "user";

// 認証不要 (読み取り or 意図的な公開エンドポイントのみ)
export const PUBLIC_ACTIONS: readonly string[] = [
  "health.check",
  "blog.recent_posted",
  "maintenance.list_active",
];

// SERVICE_ROLE_KEY Bearer 必須。オーナー資格情報での投稿や
// system 書き込みを行う action はすべてここ。
export const SERVICE_ROLE_ONLY_ACTIONS: readonly string[] = [
  "blog.auto_publish",
  "blog.create",
  "blog.backfill_from_apis",
  "x.post_with_media",
];

export function requiredAuthLevel(action: string): ActionAuthLevel {
  if (SERVICE_ROLE_ONLY_ACTIONS.includes(action)) return "service_role";
  if (PUBLIC_ACTIONS.includes(action)) return "public";
  return "user"; // どちらにも無い = ログイン user JWT 必須 (deny by default)
}
```

入口のゲートはこう変わる。

```typescript
const authLevel = requiredAuthLevel(action);
const serviceRoleRequest = isServiceRoleRequest(req);
let userId: string | null = null;

if (authLevel === "service_role" && !serviceRoleRequest) {
  return json({ error: "Unauthorized" }, 401);
}
if (authLevel === "user" && !serviceRoleRequest) {
  userId = await getUserId(req);
  if (!userId) return json({ error: "Unauthorized" }, 401);
}
```

ポイントは `requiredAuthLevel` のデフォルトが `"user"` であること。**明示的に public/service_role と宣言しない限り認証必須**になる、deny-by-default の形にした。これで「配列に足し忘れて公開されてしまう」事故が構造的に起きにくくなる。

テストはこう。判定が pure function なので副作用ゼロで固定できる。

```typescript
Deno.test("書き込み系 action は service_role 必須", () => {
  for (const a of ["blog.auto_publish", "blog.create", "x.post_with_media"]) {
    assertEquals(requiredAuthLevel(a), "service_role");
  }
});

Deno.test("未知 action は user JWT 必須 (deny by default)", () => {
  assertEquals(requiredAuthLevel("nonexistent.action"), "user");
});
```

## 「壊れないこと」をどう保証したか — 呼び出し元の全数監査

セキュリティ修正で一番怖いのは「穴は塞いだが正規の処理まで止めてしまう」こと。この 4 action の**実際の呼び出し元をすべて洗い出した**。

| Action | 呼び出し元 | 送っている鍵 |
|---|---|---|
| `blog.auto_publish` | `blog-publish.yml` / `batch_publish.py` | `SERVICE_ROLE_KEY` |
| `blog.create` | `blog-publish.yml` | `SERVICE_ROLE_KEY` |
| `blog.backfill_from_apis` | `blog-backfill-from-apis.yml` | `SERVICE_ROLE_KEY` |
| `x.post_with_media` | `post-x-with-media.yml` | `SERVICE_ROLE_KEY` |

全部 GitHub Actions のワークフローで、いずれも `Authorization: Bearer ${{ secrets.SUPABASE_SERVICE_ROLE_KEY }}` を送っていた。つまり service-role 必須にしても**正規経路は 1 つも壊れない**。ハンドラ側も `userId ?? "system"` のように null フォールバックしていたので、service-role 経路のレスポンスも DB 書き込みも従来と同一だと確認できた。

## 副作用ゼロで本番検証する

デプロイ後、本当に塞がったかを本番で確かめたい。でも `x.post_with_media` を実際に叩いたら**本物のツイートが飛ぶ**。検証のために副作用を出すわけにはいかない。そこで 2 つのテクニックを使った。

### 1. anon key で「弾かれること」を確認する

攻撃者と同じ条件、つまり Web アプリ同梱の anon key で書き込み系を叩き、**401 が返る**ことを確認する。401 なのでハンドラまで到達せず、副作用は出ない。

```bash
ANON="<web アプリに載っている anon key>"
URL="https://<project>.supabase.co/functions/v1/schedule-hub"

for a in blog.create x.post_with_media blog.auto_publish blog.backfill_from_apis; do
  printf "%s -> " "$a"
  curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST "$URL" \
    -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" \
    -d "{\"action\":\"$a\"}"
done
# => すべて HTTP 401

curl -s -o /dev/null -w "health.check -> HTTP %{http_code}\n" -X POST "$URL" \
  -H "Authorization: Bearer $ANON" -H "Content-Type: application/json" \
  -d '{"action":"health.check"}'
# => HTTP 200 (public 読み取りは無傷)
```

### 2. 「正規経路が生きている」ことは緑の cron で証明する

では service-role 経路がちゃんと通ることはどう確かめる? ワークフローを手動実行すると、また本物の投稿が飛んでしまう。

ここで使ったのが「**同じゲートを既に通過している別の非 public action の、毎日成功している cron**」だ。この EF には副作用のない集計系 action があり、それも `SERVICE_ROLE_KEY` で毎日呼ばれ、成功し続けている。EF 側の環境変数 `SERVICE_ROLE_KEY` と GitHub Secret が一致していなければその cron は落ちるはず。落ちていない = 鍵は一致している = 今回 service-role 化した 4 action も同じコードパスで通る、と間接的に証明できた。**副作用を出さずに正規経路の健全性を担保する**やり方として効いた。

## 学んだこと

- **anon key は秘密ではない**。Web アプリに同梱される時点で「実質公開」。認可の判断材料にしてはいけない。守れるのは `SERVICE_ROLE_KEY` だけ。
- **allowlist は deny-by-default にする**。「public 配列に入っているものだけ公開」より「明示宣言しない限り認証必須」の方が、足し忘れ・混入の事故に強い。
- **認可判定は pure function に切り出す**。Deno ランタイムに依存させなければ、そのまま単体テストで固定できる。
- **セキュリティ修正の検証は「弾かれること (401)」+「正規経路が別経路で生きている証拠」の2点で、副作用を出さずに完結できる**。

この修正は 3 回のセッションに分けて段階的に進めた (Qiita/dev.to のエラー挙動統一 → 書き込み系 4 action のロックダウン → 残る Notion 同期・WBS 更新系まで含めた最終ロックダウン)。最終的に `schedule-hub` の公開エンドポイントは、読み取り専用 3 種と、意図的に公開している非ログイン導線 1 種だけになった。

個人開発だと「自分しか叩かないから」と認可を後回しにしがちだが、**anon key が公開されている以上「自分しか叩かない」は成り立たない**。ハブ型 EF を書いている人は、一度 `publicActions` 相当の配列を見直してみてほしい。
