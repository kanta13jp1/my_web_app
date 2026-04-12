---
title: "Supabase Edge Function を 94本→15本に統合 + 廃止EF17本のCORS修正を一括解消した話"
tags: Flutter,Supabase,EdgeFunction,buildinpublic
topics: ["Flutter", "Supabase", "個人開発", "アーキテクチャ"]
published: false
---

# Supabase Edge Function を 94本→15本に統合 + 廃止EF17本のCORS修正を一括解消した話

## はじめに

Supabase Edge Function (EF) の上限は**プロジェクトあたり99本**です。

個人開発アプリ「自分株式会社」でFlutter Web + Supabaseを積み重ねた結果、気づいたら**94本**まで到達していました。

この記事では:
1. **94本→15本** への大幅削減 (action分岐パターン)
2. 削除したEFへの呼び出しが本番で**CORSエラー**になっていた問題の一括修正
3. GitHub Actions CI で EF 本数を自動ガードする仕組み

の3点を実装した話をまとめます。

---

## なぜ99本に引っかかったのか

機能追加のたびにEFを1本ずつ作っていました。最初のころは「関心の分離」として良いプラクティスに見えましたが、気づくと:

```
get-home-dashboard
notify-feature-request
growth-weekly-digest
development-achievements
get-admin-users
daily-judgment
ai-assistant
post-x-update
get-growth-roadmap-progress
... (あと85本)
```

機能追加のたびに1本増やす運用は **99本の壁** に必ず当たります。

---

## 解決策: action分岐パターン (hub統合)

複数のEFを1本に統合し、リクエストボディの `action` フィールドで処理を振り分けます。

```typescript
// growth-hub/index.ts
serve(async (req: Request) => {
  const body = await req.json();
  const action = body.action as string;

  switch (action) {
    case "referral.list":
      return handleReferralList(admin, userId);
    case "referral.create":
      return handleReferralCreate(admin, userId, body);
    case "acquisition.track":
      return handleAcquisitionTrack(admin, userId, body);
    case "roadmap.progress":
      return handleRoadmapProgress(admin, userId);
    // ... 16アクション
  }
});
```

### 最終的なhub構成 (15本体制)

```
standalone (4本):
  get-home-dashboard, ai-assistant,
  growth-weekly-digest, guitar-recording-studio

macro-hub (6本):
  core-hub      — 通知・メモ・フィードバック等
  growth-hub    — グロース・紹介・ロードマップ等
  ai-hub        — AI機能全般
  admin-hub     — サポート・管理・競合監視等
  app-hub       — アプリ機能全般
  schedule-hub  — スケジュール管理等

mega-hub (5本):
  tools-hub, media-hub, enterprise-hub,
  social-commerce-hub, lifestyle-hub
```

94本 → 15本 (**84%削減**)

---

## 本番CORSエラーとの戦い

hub統合でEFを削除したとき、Dart側ではまだ旧EF名を呼んでいる箇所がありました。

```
Access to XMLHttpRequest at
'https://xxx.supabase.co/functions/v1/growth-referral'
has been blocked by CORS policy: Response to preflight request
doesn't pass access control check: No 'Access-Control-Allow-Origin' header
```

**原因**: 削除されたEFへのOPTIONS (preflight) が404を返すため、ブラウザが「CORSエラー」として扱う。

実際にはCORSの設定ミスではなく、**エンドポイントが存在しない**ことが原因。404のレスポンスにはCORSヘッダーが付かないため、ブラウザにはCORSエラーに見える。

### 修正手順

```bash
# 旧EF名をgrepで洗い出し
grep -rn "廃止EF名" lib/ --include="*.dart"

# 例: growth-referral が17箇所ヒット
# → growth-hub に action 名で置き換え
```

今回修正した廃止EF一覧 (計17本):

| 廃止EF | 移行先 hub | アクション |
|--------|-----------|-----------|
| growth-referral | growth-hub | referral.list/create |
| growth-acquisition-signal | growth-hub | acquisition.track |
| feature-request-manager | core-hub | feedback.submit |
| notification-center | core-hub | notification.list/mark_read |
| development-achievements | core-hub | achievements.list/add |
| submit-feedback | core-hub | feedback.submit |
| get-growth-roadmap-progress | growth-hub | roadmap.progress |
| weather-widget | tools-hub | get_weather |
| wiki-database | enterprise-hub | wiki.* |
| voice-memo-transcriber | media-hub | transcribe.* |
| gantt-timeline-manager | enterprise-hub | gantt.* |
| code-playground | enterprise-hub | playground.* |
| spreadsheet-database | enterprise-hub | sheet.* |
| crm-sales-pipeline | enterprise-hub | crm.* |
| revenue-forecaster | enterprise-hub | forecast.list |
| real-estate-tracker | lifestyle-hub | realestate.* |
| growth-acquisition-report | growth-hub | acquisition.report |

---

## Dart側の移行パターン

```dart
// 旧コード (廃止EF)
await client.functions.invoke('growth-referral',
  body: {'action': 'get_code'});

// 新コード (hub + action)
await client.functions.invoke('growth-hub',
  body: {'action': 'referral.list'});
```

`invoke` の第1引数がEF名、`body` の `action` キーが処理の識別子になります。

---

## GitHub ActionsでEF本数を自動ガード

新規EFを野良追加しないよう、CIに50本ハードキャップチェックを追加しました。

```yaml
- name: Check Edge Function deploy count (ハードキャップ50本以下)
  run: |
    DEPLOYED=$(grep "supabase functions deploy" .github/workflows/deploy-prod.yml \
      | grep -v "^#\|#" | awk '{print $4}' | sort)
    DEPLOY_COUNT=$(echo "$DEPLOYED" | grep -c . || true)
    if [ "$DEPLOY_COUNT" -gt 50 ]; then
      echo "❌ EFハードキャップ超過: ${DEPLOY_COUNT}本 > 50本"
      exit 1
    fi
    echo "✅ EFハードキャップ内: ${DEPLOY_COUNT}本 <= 50本"
  continue-on-error: false  # 50本超過はCIブロック
```

新しいEFを追加しようとすると自動でCIが失敗します。

---

## blog.auto_publish: GitHub ActionsからのEF認証問題

副産物として、`blog-publish.yml` GitHub ActionsワークフローからSupabase EFを呼ぶ際に認証エラーが出た問題も修正しました。

**原因**: schedule-hub EF は `getUserId()` でJWT認証を要求しているが、GitHub ActionsはSERVICE_ROLE_KEYを使うため `getUser()` が null を返し、401 Unauthorized になる。

**修正**: service-to-serviceの呼び出し用に `publicActions` 配列を設置:

```typescript
// schedule-hub/index.ts
const publicActions = ["digest.run", "health.check", "blog.auto_publish", "blog.create"];
let userId: string | null = null;
if (!publicActions.includes(action)) {
  userId = await getUserId(req);
  if (!userId) return json({ error: "Unauthorized" }, 401);
}
```

`publicActions` に入れたactionはユーザー認証をスキップ。SERVICE_ROLE_KEYからの呼び出しはそのまま通過する。

---

## まとめ

| 項目 | before | after |
|-----|--------|-------|
| EF本数 | 94本 | 15本 |
| 本番CORSエラー | 17本 | 0本 |
| CI EF上限チェック | なし | 50本ハードキャップ |
| GitHub Actions認証 | 401エラー | publicActionsで解決 |

**hub統合のポイント**:
- 既存EFを削除するときは `grep -rn` で呼び出し箇所を全件確認してから
- Dart側の `invoke()` 第1引数 (EF名) と `body.action` (処理識別子) を混同しない
- CORSエラーの真因は「EFが存在しない」 = 404 → Brandsのレスポンスにヘッダーなし

Flutter × Supabase の個人開発でスケールするアーキテクチャを模索中です。
フィードバックお待ちしています。

---

URL: https://my-web-app-b67f4.web.app/
#FlutterWeb #Supabase #buildinpublic #個人開発
