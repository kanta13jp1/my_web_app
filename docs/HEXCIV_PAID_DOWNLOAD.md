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

## 公開までに残っている手順

以下は**こちら側では実行できない**、または本人の判断が要るもの。

### 1. Stripe で Price を作る

Stripe ダッシュボードで HexCiv 用の商品と Price (¥500 / 一回払い) を作成し、
その Price ID を DB に設定する。

```sql
update public.shop_products
set stripe_price_id = 'price_xxxxxxxxxxxx'
where id = 'hexciv-win64';
```

> 既存の `STRIPE_SECRET_KEY` がテストモードか本番モードかを必ず確認すること。
> テスト鍵のまま公開すると、購入は成立するのに入金されない。

### 2. 配信ファイルを置く

```bash
pwsh -File scripts/pack_release.ps1     # HexCiv リポジトリ側で実行
```

生成された `dist/HexCiv-v1.0-win64.zip` を `product-downloads` バケットの
`hexciv/HexCiv-v1.0-win64.zip` へ配置する。

manifest の `sha256` と `sizeBytes` が `shop_products` の値と**一致しているか**を
確認すること。ズレていたら、それは配信予定と違うファイルを置いている。

### 3. 特定商取引法に基づく表記 (対応済み・要確認)

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

### 4. 販売を開始する

上の3つが揃ってから初めて有効化する。

```sql
update public.shop_products set is_active = true where id = 'hexciv-win64';
```

`is_active` を既定 false にしてあるのは、**「買えたのに落とせない」事故を防ぐため**。
ファイルも価格も揃っていない状態で購入導線が出るのが最悪の順序になる。

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

- 購入・ダウンロードの UI (商品ページ / マイダウンロードページ)
- 部分返金の扱い (現状は権利を残すだけで、記録もしていない)
- 領収書の発行 (Stripe の領収書メールで代替可能かは要判断)
- Windows 以外のビルド
