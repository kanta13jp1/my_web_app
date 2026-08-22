# Issue Fix Plan #3669

- Issue: [[追加要望] 紹介報酬を不活性な500ポイントから実Stripe特典(クーポン/Proクレジット)へ接続](https://github.com/kanta13jp1/my_web_app/issues/3669)
- Labels: priority:high,追加要望,monetization,growth,acquisition
- Workflow: `.github/workflows/github-issue-fix.yml`
- CI repair pair: `.github/workflows/ci-auto-fix.yml`
- Run: https://github.com/kanta13jp1/my_web_app/actions/runs/28558847001

## Goal

[追加要望] 紹介報酬を不活性な500ポイントから実Stripe特典(クーポン/Proクレジット)へ接続

## Current Context

```text
**P1 / acquisition / owner=either**

REFERRAL_PROGRAM_DESIGN.md:37-50のgive-get 'Pro1ヶ月無料' はStripe待ちでdesign-onlyのまま。現状の唯一のlive報酬は引き換え不能な500 bonus_pointsでsignup時自動completed(gameable)。Stripeがliveになった今、UTMリンク/growth-hub EF/shareサービスという既存バイラル基盤を実際の/billingトラフィックへ変換できる最高ROIの一手。

### 受け入れ条件
- 紹介成立時にStripe coupon/Proクレジット等の実引き換え経路を付与
- /referral とshareカードにgive-get('招待された人もPro特典')を表示
- 報酬付与をsignup時自動completedからactivation gatingへ変更
- redemptionが二重付与/自己紹介で悪用されないことを確認

統括: #3663 ／ 親: 収益化 #3639


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
