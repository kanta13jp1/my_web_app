# デジタル商品ストア運用手順

Issue: [#4627](https://github.com/kanta13jp1/my_web_app/issues/4627)

AI支援の中間成果物を商品候補へ変える場合は、先に
[AI支援成果物のデジタル商品公開ループ](ARTIFACT_PUBLISHING_LOOP.md)で出所、秘密情報、
PII、権利、人間の寄与、価格、private object、SHA-256をレビューしてください。
`/admin/artifact-publishing`の`ready`はlive公開の許可ではなく、最終判断の準備完了です。

画像、音声、動画、デザイン、文章、プロンプト、アイデア、ゲーム、テンプレートを、
運営者本人が買い切り商品として販売するための手順です。第三者出品や売上分配は扱いません。

## 販売と配信の原則

- 表示価格は `shop_products.price_jpy`、実際の請求額は Stripe Price を正とします。
  公開前に両者が一致することを人が確認します。
- 商品ファイルは非公開 `product-downloads` bucket に置きます。公開URLを作りません。
- `status = 'paid'` の `shop_purchases` だけがダウンロード権利です。
- ダウンロード時に Edge Function が権利を再確認し、有効期限5分の署名URLを発行します。
- 商品を販売停止しても、購入済みユーザーの再ダウンロード権利は維持します。

## 対応する商品種別

| `product_type` | 表示 | 例 |
|---|---|---|
| `image` | 画像 | PNG/JPEG/WebP素材集、壁紙 |
| `audio` | 音声 | BGM、効果音、ナレーション |
| `video` | 動画 | MP4素材、講座、モーション素材 |
| `design` | デザイン | UIキット、ロゴ案、編集用データ |
| `writing` | 文章 | 電子書籍、記事、台本、レポート |
| `prompt` | プロンプト | AI用プロンプト集、ワークフロー |
| `idea` | アイデア | 企画書、コンセプト集、事業アイデア |
| `game` | ゲーム | Windowsゲーム、追加コンテンツ |
| `application` | アプリ | Windowsアプリ、デスクトップツール |
| `template` | テンプレート | 表計算、文書、スライド、制作雛形 |

複数ファイルはZIPにまとめます。`download_file_name` は購入者に表示する保存名で、
パス区切りや制御文字は使えません。

## 1. 権利と商品説明を確認する

公開前に、次を記録してください。

- 自分が販売・商用利用を許諾できる素材だけで構成されている
- AI生成物の場合、利用したモデル・素材・フォント・音源の規約上、販売可能である
- 実在人物の肖像、声、商標、著作物を無断で含めていない
- 購入者ができること（個人利用、商用利用、改変、成果物への組込み）
- 購入者ができないこと（素材そのものの再配布・再販売、共有）
- ファイル形式、必要アプリ、対応OS、容量、バージョン

商品ページの `license_summary_ja` は短い要約です。個別ライセンス全文が必要な商品は、
配信ZIP内にも `LICENSE.txt` を含めます。

## 2. 配信ファイルを確定する

最終ファイルを作り、サイズとSHA256を取得します。

```powershell
$productFile = 'C:\path\to\product.zip'
$fileInfo = Get-Item -LiteralPath $productFile
$sha256 = (Get-FileHash -LiteralPath $productFile -Algorithm SHA256).Hash.ToLowerInvariant()
$fileInfo.Length
$sha256
```

ファイル確定後は同じ版番号のまま中身を差し替えません。修正時は版番号、保存パス、
SHA256、サイズをすべて更新します。

## 3. 非公開Storageへアップロードする

`product-downloads` bucket が `public = false` であることを確認し、商品IDと版番号を含む
不変パスへアップロードします。

```text
product-downloads/<product-id>/<product-id>-v<version>.zip
```

アップロード後に実測サイズとSHA256がローカルの値と一致することを確認します。
サービスロールキーや署名URLをIssue、ログ、スクリーンショットへ残さないでください。

## 4. Stripe Product / Priceを作る

Stripeで一回払いのProductとJPY Priceを作成します。価格は50円以上とし、
`price_...` を控えます。テスト/本番のPriceと `STRIPE_SECRET_KEY` のmodeを混在させません。

## 5. 商品を非公開で登録する

最初は必ず `is_active = false` で登録します。

```sql
insert into public.shop_products (
  id,
  name_ja,
  summary_ja,
  description_ja,
  price_jpy,
  stripe_price_id,
  storage_path,
  version,
  file_size_bytes,
  sha256,
  product_type,
  format_label,
  requirements_ja,
  license_summary_ja,
  download_file_name,
  preview_image_url,
  sort_order,
  is_active
)
values (
  '<product-id>',
  '<商品名>',
  '<一覧用の短い説明>',
  '<詳細説明>',
  <税込表示価格>,
  'price_xxx',
  '<product-id>/<product-id>-v1.0.zip',
  '1.0',
  <実測バイト数>,
  '<64文字のsha256>',
  'template',
  'ZIP / PDF',
  '<必要なOS・アプリ>',
  '<利用許諾の要約>',
  '<購入者に表示する安全なファイル名>.zip',
  null,
  100,
  false
);
```

プレビュー画像を設定する場合、`preview_image_url` は一般公開してよいHTTPS画像だけを
指定します。有料ファイル本体や秘密情報をプレビューURLへ置かないでください。

## 6. 非公開状態で検証する

本番反映の順序は、DB migration → `shop-checkout` / `shop-download` → Flutter Webです。
公開前に次を確認します。

1. DBの表示価格、Stripe Price、通貨、一回払いが一致する
2. Storage object、サイズ、SHA256、MIMEが一致する
3. `/shop/product?product_id=<product-id>` の説明、形式、ライセンスが正しい
4. 未購入者は `shop-download` で403、別ユーザーの購入行はRLSで読めない
5. Checkout戻り先に同じ `product_id` が残る
6. 決済直後に購入ボタンが再表示されず、Webhook反映待ちになる
7. 購入済みライブラリから再ダウンロードできる
8. 返金Webhook後は権利が失効する

## 7. 販売を開始・停止する

法務表示と検証が完了した後だけ公開します。

`artifact_candidates.product_id`にlinkした商品は、候補が`ready`で全hard gateと人手承認を
満たすまで、DB triggerが`is_active = true`を拒否します。次のSQLは対象、環境、価格、
Storage実測値、rollback手順を人が再確認し、live DB変更を明示承認した後だけ実行します。

```sql
update public.shop_products
set is_active = true,
    published_at = coalesce(published_at, now())
where id = '<product-id>';
```

問題時は `is_active = false` で新規販売を停止します。購入済みユーザーの権利行や
配信ファイルは削除しません。返金はStripe上の決済とWebhook証跡を照合して扱います。

## 完了証跡

商品公開だけでは収益化完了ではありません。外部購入者のlive決済、Webhook、配信、
Stripe Payout、銀行着金を同じ証跡で照合した時点で、初めて売上完了とします。
