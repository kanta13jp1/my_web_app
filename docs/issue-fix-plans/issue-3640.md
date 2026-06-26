# Issue Fix Plan #3640

- Issue: [[追加要望] 特定商取引法に基づく表記ページ作成 (assets/legal/tokushoho.md + /tokusho)](https://github.com/kanta13jp1/my_web_app/issues/3640)
- Labels: priority:high,追加要望,monetization
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28211236842

## Goal

[追加要望] 特定商取引法に基づく表記ページ作成 (assets/legal/tokushoho.md + /tokusho)

## Current Context

```text
**P0 / 法務必須 / go-live blocker.** 日本の消費者に課金するには特定商取引法に基づく表記が実質必須。現状は privacy のみ存在。

`PrivacyPolicyPage`（`lib/pages/privacy_policy_page.dart`、markdownアセット描画）パターンを複製。`assets/legal/` は pubspec で**ディレクトリ登録済**（pubspec変更不要）。

### 受け入れ条件
- `assets/legal/tokushoho.md` 作成（必須項目: 販売事業者名 / 運営責任者 / 所在地 / 連絡先 / 販売価格 Pro¥980・Team¥2,980 税込 / 商品代金以外の必要料金 / 支払方法(クレカ=Stripe) / 支払時期 / 役務提供時期=決済完了後ただちに / 返品・キャンセル・解約条件 / 動作環境）。実名・連絡先は `{{OPERATOR_LEGAL_NAME}}` `{{CONTACT}}` プレースホルダ
- `TokushohoPage` widget + `/tokusho` ルートを `lib/main.dart` と `lib/main_mobile.dart` に登録
- `subscription_billing_page.dart` の決済面にリンク表示
- `flutter analyze` clean

統括: #3639


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
