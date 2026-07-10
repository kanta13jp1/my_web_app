# Issue Fix Plan #3745

- Issue: [[追加要望][first-user] T1: X 個人開発ローンチ投稿（下書き完成済・コピペ可）](https://github.com/kanta13jp1/my_web_app/issues/3745)
- Labels: 追加要望,priority:critical,acquisition,launch,first-user
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/29069352848

## Goal

[追加要望][first-user] T1: X 個人開発ローンチ投稿（下書き完成済・コピペ可）

## Current Context

```text
**P0 / owner=user（投稿）+claude（下書き済）**

X（@側アカウント）に**手動の個人開発ローンチ投稿**を1本。自動マーケ投稿ではなく一人称の「作りました」投稿が #個人開発 コミュニティに最も刺さる。

### 投稿文（完成済・コピペ可）
```
人生を「会社経営」みたいに管理できたら…と思って、自分専用の経営アプリを1人で作りました🏢

「自分株式会社」— あなたが人生のCEO
・収支・資産/負債の見える化（CFO室）
・AIアシスタントに何でも相談（参謀）
・タスク/目標のWBS管理（PM）
・150社のAIを学べるAI大学

無料で使えます👇
https://my-web-app-b67f4.web.app/

#個人開発 #買い切りじゃないけど無料
```

### 手順
1. 上記をコピー（文言の微調整は自由）
2. **スクショを1枚添付**（推奨: ホームの全機能グリッド or 資産管理ダッシュボード。数字が映えるもの）
3. 投稿 → 返信には全部返す（アルゴリズム的にも初期エンゲージが命）

### 受け入れ条件
- X に投稿されている（URL をこの Issue にコメント）
- 24h 後のインプレッション/プロフィールクリックを記録

統括: #3744


```

## Autonomous Repair Loop

1. Reproduce the smallest failing path for this issue.
2. Apply the minimum safe fix on this branch.
3. Let normal CI run on the draft PR.
4. If CI fails on mechanical issues, `ci-auto-fix.yml` attempts `dart fix --apply` and `deno fmt`.
5. Merge only after CI is green and the issue scope is satisfied.

## Checklist

- [ ] Reproduction is clear
- [ ] Smallest safe fix is implemented
- [ ] Analyze/tests/CI are checked
- [ ] PR notes explain the change and the remaining risk
