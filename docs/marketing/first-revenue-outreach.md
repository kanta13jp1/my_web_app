# First Revenue Outreach Kit

Date: 2026-06-27 JST

Use this only after the live revenue gate passes with a `cs_live...` Checkout
session:

```powershell
C:\Users\kanta\AppData\Local\Programs\Python\Python312\python.exe scripts\check_first_revenue_readiness.py --mode live --json
```

Do not publish these posts while the gate returns `cs_test...`.
Also do not publish while the Stripe Dashboard account-status tab shows
overdue identity verification or paused payouts. The current known blocker is
`担当者の本人確認書類を提出する`.

## Target

Get one real Founding Supporter payment through the public supporter Checkout,
then verify:

1. Stripe live payment succeeded.
2. `stripe-webhook` recorded `hub_data.source = stripe_supporter_payment`.
3. Stripe payout reaches the bank account with a credited amount of at least
   1 JPY.

## Link

Use the public paid route:

```text
https://my-web-app-b67f4.web.app/subscription-billing
```

## Short X Post

```text
自分株式会社OSの最初の有料サポーターを募集します。

AIツール、学習、資産管理、仕事の意思決定をひとつの個人OSにまとめる実験を公開開発中です。
よければ Founding Supporter として100円で応援してください。

https://my-web-app-b67f4.web.app/subscription-billing
```

## Direct Message

```text
今、自分株式会社OSという個人向けAI/仕事/学習/資産管理ツールを公開開発しています。

Stripe本番決済の初回検証も兼ねて、Founding Supporterを100円で募集しています。
もしコンセプトが面白そうなら、ここから支援してもらえるとかなり助かります。

https://my-web-app-b67f4.web.app/subscription-billing
```

## Blog/Build In Public Note

```text
今日の公開開発ログ:

自分株式会社OSにStripe本番決済のFounding Supporter導線を追加しました。
最初の目標は大きな売上ではなく、実際に1円以上が銀行口座へ入金されるところまでを確認することです。

もしこの実験を応援してもいいと思った方は、100円のFounding Supporterで支援できます。

https://my-web-app-b67f4.web.app/subscription-billing
```

## Outreach Log

Record each concrete attempt before waiting on passive traffic:

| # | Channel | Target | Posted/Sent At | Result |
|---|---|---|---|---|
| 1 | X | Public post | | |
| 2 | Direct | Known contact | | |
| 3 | Blog | Build-in-public post | | |
| 4 | Community | Approved community | | |
| 5 | Direct | Known contact | | |
| 6 | Direct | Known contact | | |
| 7 | X | Follow-up reply/thread | | |
| 8 | Blog | Short update | | |
| 9 | Direct | Known contact | | |
| 10 | Direct | Known contact | | |

Stop the sprint once the first successful payment is captured. Switch to
webhook evidence and bank payout verification.
