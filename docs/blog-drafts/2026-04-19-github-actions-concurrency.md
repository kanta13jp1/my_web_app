---
title: "GitHub Actions concurrencyの落とし穴 — cancel-in-progress: falseでもqueuedは消える"
tags: GitHubActions,CI/CD,buildinpublic,個人開発
published: false
---

# GitHub Actions concurrencyの落とし穴

## TL;DR

`cancel-in-progress: false` は **実行中のrun** を守るだけで、**queuedのrun** は後発のrunに上書きキャンセルされる。

## 問題: 連続pushで6本がcancelled

```
deploy-prod cancelled 2026-04-19T10:00:59
deploy-prod cancelled 2026-04-19T10:02:30
deploy-prod cancelled 2026-04-19T10:04:03
deploy-prod cancelled 2026-04-19T10:07:30
deploy-prod cancelled 2026-04-19T10:08:41
deploy-prod cancelled 2026-04-19T10:08:56
deploy-prod success  2026-04-19T10:09:34  ← 最後の1本だけ実行
```

設定は `cancel-in-progress: false` のはずなのに、なぜ？

## GitHub Actions concurrencyの実際の動作

```yaml
concurrency:
  group: deploy-prod
  cancel-in-progress: false
```

この設定の正確な意味:

| 状態 | cancel-in-progress: true | cancel-in-progress: false |
|---|---|---|
| **実行中のrun** | キャンセルされる | **キャンセルされない** ✅ |
| **queued (待機中) のrun** | キャンセルされる | **キャンセルされる** ⚠️ |

**ポイント**: `cancel-in-progress` が制御するのは「実行中」のrunのみ。queuedのrunは常に1本しか存在できず、新しいrunが来ると古いqueuedrunは問答無用でキャンセルされる。

## なぜこうなるのか

GitHub Actionsのconcurrencyグループは以下のルールで動く:

1. 同じgroupで **実行中** のrunは最大1本
2. 同じgroupで **queued** のrunも最大1本
3. 新しいrunが来たとき:
   - 実行中のrunがある → `cancel-in-progress`の値に従う
   - queuedのrunがある → **常にキャンセルして新しいrunをqueue**

つまり「queue = 次に実行される1本の予約席」であり、常に最新のrunで上書きされる。

## 今回の事象の解釈

blog-publishワークフローが10分間に8本連続でcommitを生成 → 8本のdeploy-prodがトリガー:

```
push #1 → deploy A: running
push #2 → deploy B: queued   (Aが終わるまで待機)
push #3 → deploy C: queued   (Bをキャンセル、Cがqueue)
push #4 → deploy D: queued   (Cをキャンセル、Dがqueue)
...
push #8 → deploy H: queued   (最後の1本がqueue)
deploy A 完了 → deploy H: running → success
```

結果: #2〜#7 はキャンセル (6本)、#1と#8だけ実行 (2本success)。

## これは問題か？

**今回のケースでは問題なし。** なぜなら:

- blog-publishのcommitは `published: true` マーカーのみ
- deploy #8が実行されれば最新状態が反映される
- 中間の#2〜#7をスキップしても最終状態は同じ

**問題になるケース:**

```yaml
# 各commitに異なる意味がある場合 (例: DB migration)
# migration A → migration B → migration C が順番に必要な場合、
# B と C がキャンセルされると A だけ適用されてしまう
```

## 対策パターン

### パターン1: 現状維持 (最終状態が同じなら十分)

```yaml
concurrency:
  group: deploy-prod
  cancel-in-progress: false
```

フロントエンドデプロイ・静的ファイル更新など、「最新が反映されればOK」な場合はこれで十分。

### パターン2: concurrencyを外してキューを保証

```yaml
# concurrencyなし → 全runが並列実行 (deploy競合に注意)
# または
concurrency:
  group: ${{ github.sha }}  # 各commitに固有のgroup
  cancel-in-progress: false
```

各commitを必ず実行したい場合は`group`をcommit固有にする。ただしリソース消費に注意。

### パターン3: pathsフィルターで不要triggerを減らす

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'lib/**'
      - 'supabase/functions/**'
      - '!docs/blog-drafts/**'  # blogの published:true 変更では不要
```

根本対策: deployが不要なcommitではworkflowをスキップする。

## まとめ

| 設定 | running保護 | queued保護 | 推奨ユースケース |
|---|---|---|---|
| `cancel-in-progress: true` | ❌ | ❌ | 高速iteration・中断OKなCI |
| `cancel-in-progress: false` | ✅ | ❌ | フロントエンドデプロイ (最新反映が目的) |
| `group: ${{ github.sha }}` | — | ✅ (全実行) | DB migration・順序依存deploy |

`cancel-in-progress: false` を「全runが実行される」と誤解しがち。正確には「実行中のrunを守る」設定。キャンセル多発を見て焦る前に、最終状態が正しければOKと判断できる。

---
自分株式会社: https://my-web-app-b67f4.web.app/
#GitHubActions #CICD #buildinpublic #個人開発
