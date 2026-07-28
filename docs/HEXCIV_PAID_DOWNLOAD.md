# HexCiv 有料ダウンロード販売

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
| `stripe-webhook` (拡張) | 購入行の作成 | `stripe_checkout_session_id` の unique + `onConflict` で**再送に対して冪等**。`payment_status` が paid でなければ `pending` で作る |
| `shop-download` | 署名付きURL発行 | 権利確認 → 有効期限 **5分**の URL。販売停止 (`is_active=false`) でも**購入済みの人には配信する** |

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

### 3. 特定商取引法に基づく表記を用意する

日本国内で継続的に有料販売する場合、通信販売として**表示が義務付けられる**項目がある。
最低限、以下を1ページにまとめて常時アクセスできるようにする。

| 項目 | 備考 |
|---|---|
| 販売事業者名 | 個人の場合は氏名 |
| 所在地 | 個人の場合は住所 |
| 連絡先 | 電話番号・メールアドレス |
| 販売価格 | ¥500 (税込) と明記 |
| 対価以外の必要料金 | 通信料は購入者負担、など |
| 支払方法・支払時期 | クレジットカード / 購入時 |
| 引渡時期 | 決済完了後ただちにダウンロード可能 |
| **返品・キャンセル** | デジタル商品につき原則不可、とするなら**その旨を明記**する必要がある |
| 動作環境 | Windows 10/11 64bit など |

**注意すべき点が2つある。**

- **住所・電話番号の公開**: 個人事業では自宅住所と電話番号の掲載が問題になりやすい。
  BOOTH や itch.io のようなプラットフォーム経由なら事業者情報の表示を
  プラットフォームが担うため、この負担を避けられる。自前サイトで売る以上は
  この点を自分で引き受けることになる。
- **返品特約**: 表示がないと、法定のルールが優先されて「返品不可」を主張できなく
  なりうる。デジタル商品で返金を受け付けない方針なら、**購入前に見える位置**に
  明記しておく。

税務 (消費税の課税事業者かどうか、インボイス登録の要否) も売上規模により関係する。
ここは税理士に確認するのが確実。

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
- **返金時**: Stripe 側で返金しても `shop_purchases.status` は自動では変わらない。
  現状は手動で `refunded` に更新する必要がある (`charge.refunded` の webhook 対応は未実装)。
- **版を上げるとき**: `pack_release.ps1` を実行 → 新しい zip をバケットへ配置 →
  `shop_products` の `version` / `storage_path` / `sha256` / `file_size_bytes` を更新。
  購入済みの利用者は追加の支払いなく最新版を落とせる (権利は商品単位のため)。

## まだ無いもの

- 購入・ダウンロードの UI (商品ページ / マイダウンロードページ)
- `charge.refunded` を受けて `status` を `refunded` にする webhook 分岐
- 領収書の発行 (Stripe の領収書メールで代替可能かは要判断)
- Windows 以外のビルド
