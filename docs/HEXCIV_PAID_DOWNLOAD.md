# HexCiv 有料ダウンロード販売

> 汎用デジタル商品ストアへの商品追加は
> [`docs/DIGITAL_PRODUCT_STORE.md`](DIGITAL_PRODUCT_STORE.md) を参照してください。
> HexCiv固有のビルド・配布情報は本書に残します。

自分株式会社のサイトから HexCiv (Unity 製 Windows ゲーム) を買い切りで配布する仕組み。

- 価格: **¥500** (税込)
- 配信: Supabase の**非公開バケット** + 有効期限付き署名付きURL
- 購入: サイトへ**ログインしてから** Stripe Checkout
- HexCiv リポジトリは**公開のまま**。ソースからの個人利用ビルドは許可し、
  ビルド済みバイナリの再配布と商用利用を禁じる ([`HexCiv/LICENSE.md`](https://github.com/kanta13jp1/HexCiv/blob/main/LICENSE.md))

> 本ドキュメントの法務に関する記述は**法的助言ではありません**。実際の表記内容は
> ご自身で確認・判断してください。

## 全体の流れ

```
利用者                サイト                Edge Function          Stripe        Supabase
  │  購入する         │                        │                     │              │
  ├──────────────────>│  shop-checkout ───────>│  Checkout 作成 ────>│              │
  │<───────────────── Checkout URL ────────────┤                     │              │
  ├── 決済 ───────────────────────────────────────────────────────> │              │
  │                   │                        │<── webhook ─────────┤              │
  │                   │            stripe-webhook が購入行を作成 ───────────────────>│
  │  ダウンロード      │                        │                     │   shop_purchases
  ├──────────────────>│  shop-download ───────>│  権利確認 ──────────────────────── >│
  │<───── 署名付きURL (5分) ────────────────────┤                     │  非公開バケット
```

## 実装済みの構成要素

### DB (`supabase/migrations/20260728010000_create_shop_product_downloads.sql`)

| テーブル | 役割 |
|---|---|
| `shop_products` | 買い切り商品のカタログ。`is_active` が true のものだけ販売・配信対象 |
| `shop_purchases` | 購入記録。**`status = 'paid'` の行がダウンロード権利そのもの** |
| `shop_download_events` | 署名付きURLの発行記録 (監査用) |

バケット `product-downloads` は **`public = false`**。ここを true にすると URL を
知る全員が落とせるため、有料化が成立しなくなる。

RLS の方針は「**読みは本人分だけ・書きは service role だけ**」。
`shop_purchases` に insert ポリシーを**意図的に作っていない**のがポイントで、
利用者のトークンで購入行を作れると支払わずに権利を得られてしまう。

### Edge Function

| 関数 | 役割 | 要点 |
|---|---|---|
| `shop-checkout` | Checkout セッション作成 | 金額は**決めない**。Stripe の Price を参照するだけ (価格の二重管理を避ける)。`metadata` に `user_id` と `shop_product_id` を載せる |
| `stripe-webhook` (拡張) | 購入行の作成 / 返金時の権利失効 | `stripe_checkout_session_id` の unique + `onConflict` で**再送に対して冪等**。`payment_status` が paid でなければ `pending` で作る。`charge.refunded` (全額) で `status` を `refunded` にする |
| `shop-download` | 署名付きURL発行 | 権利確認 → 有効期限 **5分**の URL。販売停止 (`is_active=false`) でも**購入済みの人には配信する** |

### Stripe API バージョン (2026-07-29)

webhook endpoint は **2026-06-24.dahlia** で作り直した。元の 2020-03-02 では
checkout session に `payment_status` が無く、`checkoutPaymentDecision()` が
「paid でなければ履行しない」で必ず止まるため、**購入が一切記録されなかった**。

注意すべきなのは、この EF には**2つの API バージョンが同時に流れ込む**こと。

| 経路 | 適用されるバージョン |
|---|---|
| webhook event の payload | endpoint に固定した **2026-06-24.dahlia** |
| `stripeGet()` の戻り値 | `Stripe-Version` ヘッダ未指定 = **アカウント既定バージョン** |

`upsertSubscriptionFromStripe()` はこの両方から呼ばれるため、片方の形しか
読まない実装はもう片方で静かに null を書き込む。差の吸収は
`stripe_api_compat.ts` に集約してある (2025-03-31.basil で **削除** された
2フィールド — `invoice.subscription` と `subscription.current_period_end`)。

> アカウント既定バージョンを引き上げても、この層は無害に効き続ける。
> 「旧形はもう来ないから」と fallback を消すと、既定バージョンが古いままの
> `stripeGet()` 経路が先に壊れる。消す前に Workbench で既定バージョンを確認すること。

## 本番稼働状況 (2026-08-22確認)

HexCiv の有料ダウンロード販売は既に本番で稼働している。

| 項目 | 確認結果 |
|---|---|
| 商品ページ | `https://my-web-app-b67f4.web.app/shop/hexciv` で表示 |
| 商品 | `hexciv-win64` / HexCiv (Windows 版) |
| 価格 | **¥500 税込・買い切り** |
| Stripe | Price ID 設定済み。購入ボタンはログイン後に Checkout を開始 |
| 配信 | 非公開 `product-downloads` バケットから購入者へ5分間の署名URLを発行 |
| 商品状態 | `is_active = true` |
| Edge Function | `shop-checkout` / `shop-download` / `stripe-webhook` は ACTIVE |
| 認証境界 | 未認証の購入・取得は401、署名なし webhook は400 |

現在の配布ファイルは次の内容でカタログに登録されている。

| フィールド | 現在値 |
|---|---|
| `storage_path` | `hexciv/HexCiv-v1.0-win64.zip` |
| `version` | `1.0` |
| `file_size_bytes` | `37,572,177` |
| `sha256` | `cc0e5caae732fa123d26ed62c1827a923c4ccd777823190ed714ba178e97ed93` |

## 最新版へ安全に切り替える手順

配信中オブジェクトを直接上書き・削除しない。新しいZIPを一意なパスへ置き、
ハッシュと容量を確認してから商品行の参照先だけを切り替える。

### 1. 候補を検証する

HexCiv 側の `sales_candidate.json` と manifest を正本として、ZIPの SHA-256・容量、
Windows起動、スモークテスト、同梱ライセンスを確認する。

### 2. 一意なパスへアップロードする

同名ファイルの上書きはせず、候補IDを含むパスを使う。例:

```text
product-downloads/hexciv/releases/stage4m-20260814/HexCiv-v1.0-win64.zip
```

アップロード後にリモート側の容量と SHA-256 が候補 manifest と一致するまで
カタログを変更しない。

### 3. 商品行を一度に切り替える

トランザクション内で `storage_path` / `version` / `sha256` /
`file_size_bytes` を同時更新する。`price_jpy`、`stripe_price_id`、`is_active` は
変更しない。

### 4. 購入済みテストアカウントで確認する

新規の実課金は行わず、既存の購入済みテストアカウントで署名URLを発行し、
ダウンロードしたZIPの容量と SHA-256 を照合する。

### 5. ロールバック可能なまま保持する

検証期間中は旧オブジェクトを削除しない。不具合時は商品行の4フィールドを
上表の現在値へ戻すだけで旧版へ復旧できる。

## 特定商取引法に基づく表記 (対応済み・要確認)

**このページは既に存在する** (`/tokusho` → `assets/legal/tokushoho.md`)。事業者名・連絡先・
支払方法・返品の方針は記載済みで、住所と電話番号は「請求があれば遅滞なく開示」という
個人事業主向けの扱いになっている。

買い切り商品はこの表記に**含まれていなかった**ため、今回あわせて追記した。

| 追記した項目 | 内容 |
|---|---|
| 販売価格 | HexCiv (Windows 版) ¥500 買い切り / 継続課金なし・再ダウンロード可 |
| 支払時期 | Stripe Checkout 完了時に一度だけ課金 |
| 引渡時期 | 決済完了後ただちに (反映に数秒かかる場合あり) |
| 返品・キャンセル | デジタル商品につき原則不可 (既存の方針をそのまま適用) |
| 動作環境 | Windows 10 / 11 (64bit)、約36MB / 展開後約92MB |

> 記載内容が実態と合っているか、返品不可の方針でよいかは**本人の確認が必要**。
> 税務 (消費税の課税事業者かどうか、インボイス登録の要否) も売上規模により関係する。
> ここは税理士に確認するのが確実。

## 運用上の注意

- **署名付きURLは共有可能**。有効期限内 (5分) なら URL を知る誰でも落とせる。
  期限を延ばすほど実質的な再配布リンクになるので、安易に伸ばさない。
- **発行回数は記録するが止めていない**。PC 故障や再インストールでの正当な
  再ダウンロードを機械的に阻むと、問い合わせ対応の方が高くつくため。
  `shop_download_events` を定期的に見て、異常な回数があれば個別に対処する。
- **返金時**: `charge.refunded` を受けて `shop_purchases.status` を `refunded` に
  自動更新する (2026-07-30 実装 / 手動更新は不要になった)。紐付けは
  `stripe_payment_intent_id`。**失効させるのは全額返金のときだけ** —
  部分返金で権利を消すと、支払った分が残っている利用者から取り上げてしまう。
  🔴 **Stripe 側で `charge.refunded` を購読していないと、この分岐は永久に動かない。**
  Webhook endpoint の送信イベント一覧に入っているか確認すること (入っていなくても
  コードも CI も緑のままなので、気付く手掛かりが無い)。動作確認は返金を 1 件試して
  EF ログに `refund_revoked` が出るかを見るのが確実。
- **版を上げるとき**: `pack_release.ps1` を実行 → 新しい zip をバケットへ配置 →
  `shop_products` の `version` / `storage_path` / `sha256` / `file_size_bytes` を更新。
  購入済みの利用者は追加の支払いなく最新版を落とせる (権利は商品単位のため)。

## まだ無いもの

- 部分返金の扱い (現状は権利を残すだけで、記録もしていない)
- 領収書の発行 (Stripe の領収書メールで代替可能かは要判断)
- Windows 以外のビルド
- Windows実行ファイルのコード署名。SmartScreen警告を減らすには別途証明書が必要
