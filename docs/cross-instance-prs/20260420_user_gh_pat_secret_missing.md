# ユーザー action 必要: GH_PAT secret 未設定で deploy-prod "Push Release Tag" 常時失敗

**From**: PS版#1 S17 (2026-04-20 18:24 JST)
**To**: ユーザー (kanta13jp1) / optional: PS版#5 on-call
**Priority**: 🟡 Medium (cosmetic — deploy 本体は成功)
**Action type**: 外部 secret 設定

---

## 症状

`Deploy to Production` workflow の `Push Release Tag` step で以下エラー:

```
! [remote rejected]   v1.0.1182 -> v1.0.1182
  (refusing to allow a GitHub App to create or update workflow
  `.github/workflows/ai-university-update.yml` without `workflows` permission)
error: failed to push some refs to 'https://github.com/kanta13jp1/my_web_app'
```

Firebase hosting / Supabase EF (17 本) の deploy **本体は毎回成功**。
tag push + Release 作成のみ失敗。

## Root cause

1. `deploy-prod.yml` L69 で `token: ${{ secrets.GH_PAT || secrets.GITHUB_TOKEN }}` 指定
2. `gh secret list` で `GH_PAT` **不在** → `GITHUB_TOKEN` (GitHub App) にフォールバック
3. GitHub App token には `workflows` permission がない → 履歴内に `.github/workflows/*.yml` 変更を含む tag 作成拒否
4. Win版#131 part 9 で「GH_PAT で push 認証」と yml に書いたが secret 本体は設定されないまま

## 必要アクション (ユーザー only)

PAT 作成 + secret 設定:

```bash
# 1. https://github.com/settings/tokens で「Fine-grained PAT」作成
#    - Repository access: kanta13jp1/my_web_app
#    - Permissions: Contents: Read/Write, Actions: Read/Write, Workflows: Read/Write
#    - 有効期限: 1 年

# 2. 作成した PAT を GH_PAT として登録
gh secret set GH_PAT --repo kanta13jp1/my_web_app
# → 貼り付け

# 3. 検証
gh workflow run deploy-prod.yml  # 手動 trigger
gh run watch  # Push Release Tag 通過確認
```

## 代替案 (ユーザー判断)

PAT 運用したくない場合:

- **Option A**: `Push Release Tag` step を non-blocking 化 (`|| echo "Tag push skipped (GH_PAT未設定)"`)
- **Option B**: Release tagging を別 WF へ分離 (GITHUB_TOKEN のみで済むよう commit range を非 workflow commit のみに限定)
- **Option C**: 完全削除 (version tagging 不要と判断)

PS版#1 推奨: **PAT 設定 (本流)**。tag + Release は運用監視で有用。

## 関連 memory

- `memory/feedback_correction_20260420_workflow_tag_push_permission.md` (Win#131 part 9 命名)
- `memory/project_20260420_ps1_s17.md` (本件検出)

## 影響度

- deploy 本体: ✅ 成功 (毎回)
- tag push: ❌ 失敗 (毎回)
- GitHub Release: ❌ tag 不在で作成されず
- Sentry release tracking 等: 影響なし (使っていない)
- 運用監視: 「毎 deploy 失敗扱い」で dashboard ノイズ
