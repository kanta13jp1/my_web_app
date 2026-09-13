# Supabase カスタムドメイン導入判断・切替計画

- 対象 Issue: [#1290](https://github.com/kanta13jp1/my_web_app/issues/1290)
- 対象 Supabase project: `my-web-app` (`smmkxxavexumewbfaqpy`)
- 作成日: 2026-08-26 JST
- 現在の判定: **No-Go（費用承認、利用ドメイン、DNS管理者が未確定）**

## 結論

Supabase のカスタムドメインは、Firebase Hosting で配信している Web サイトの
`https://my-web-app-b67f4.web.app/` を独自ドメインへ変更する機能ではない。
変更できるのは Supabase API、Auth、Edge Functions、Storage のホスト名であり、
このプロジェクトでは例えば `api.<承認済みドメイン>` を使う判断になる。

したがって、単に一般ユーザーが見る Web サイトのブランドURLを改善したいだけなら、
この追加費用を承認する根拠は弱い。OAuth 同意画面の表示、外部向け API / webhook の
長期的な可搬性、Supabase URL を外部へ公開する場面に価値があると判断できる場合に限り、
Pro + Custom Domain を承認する。

現時点では次が未確定なため、アップグレード、ドメイン登録、DNS変更、
`supabase domains create/activate` は実行しない。

- 月額上限と支払方法の承認
- 正確な FQDN（例は `api.<承認済みドメイン>`。実在ドメインは推測しない）
- DNS レジストラと変更担当者
- OAuth/SAML の利用状況および外部連携先の変更担当者

## 費用対効果

### 公式料金（2026-08-26 確認）

| 項目 | 料金 | 備考 |
| --- | ---: | --- |
| Pro plan | USD 25/月 | paid organization の基本料金 |
| Compute Micro | USD 10/月相当 | USD 10/月の compute credit で相殺可能 |
| Compute Small | USD 15/月相当 | credit 適用後の増分は USD 5/月相当 |
| Custom Domain | USD 0.0137/時（約 USD 10/月） | 1時間未満は1時間として計上。Spend Cap 対象外 |

目安は以下。税、為替、超過使用量、追加 project、その他 add-on は含まない。

- Micro 1 project: `25 + 10 + 10 - 10 = 約 USD 35/月`（約 USD 420/年）
- 公式の Small 1 project 例: `25 + 15 + 10 - 10 = 約 USD 40/月`
  （約 USD 480/年）

Custom Domain は時間課金なので厳密な定額ではない。31日間で744時間の場合は
USD 10を少し超える場合がある。社内承認額は最低額だけでなく、Smallを使う場合の
**USD 40/月 + 税 + 従量超過**を基準にする。

### 期待できる効果

- OAuth 同意画面に project ref ではなくブランド化した API ドメインを表示できる。
- 外部 API、webhook、QRコード、保存済みURLを Supabase project ref から分離できる。
- 将来 project を移行しても CNAME の向き先変更で外部向けURLを維持しやすい。
- Pro のバックアップ、ログ保持、容量上限なども同時に利用できる。

### このプロジェクトで効果が限定的な点

- フロントエンドは Firebase Hosting であり、Supabase Custom Domain では
  Web サイトの公開URL、canonical、OGP、SEO URLは変わらない。
- 外部向け API の主要な顧客・契約・SLA がまだ確認できていない。
- 既定 Supabase URL は activation 後も利用できるため、内部処理を急いで全面変更する
  必要はない。一方で二重URL期間の管理コストは発生する。

### 代替案

1. Web サイトのブランディングが目的なら Firebase Hosting の custom domain を別途検討する。
2. Pro の他の機能も必要だが独自所有ドメインまでは不要なら、Pro で利用可能な
   Supabase vanity subdomain（experimental）の適合性を別途確認する。
3. 現状維持とし、外部 API / OAuth の露出が増えた時点で本計画を再評価する。

Custom Domain と vanity subdomain は同一 project で併用できない。

## 現在構成と影響範囲

### 正本

- Flutter Web 配信: Firebase project `my-web-app-b67f4`
- 本番 Web URL: `https://my-web-app-b67f4.web.app/`
- Supabase project URL: `https://smmkxxavexumewbfaqpy.supabase.co`
- Flutter の Supabase URL: `lib/services/supabase_runtime_config.dart` の既定値、または
  build-time `SUPABASE_URL`
- 本番 deploy: GitHub secret `SUPABASE_URL_PROD` を `--dart-define=SUPABASE_URL=...` へ渡す
- Google OAuth のアプリ内 `redirectTo`: Web の実行 origin (`Uri.base.resolve('/')`)

ローカル `supabase/config.toml` の `site_url` / `additional_redirect_urls` は localhost 用で、
Supabase production dashboard の Auth URL 設定の正本ではない。

### 既定 Supabase URL の棚卸し

2026-08-26 の `rg --hidden` 走査では、docs を除く75ファイルに project ref の直書きがある。

| 区分 | ファイル数 | 移行方針 |
| --- | ---: | --- |
| `.github` | 52 | workflows 51本 + その他1本。まず `SUPABASE_URL_PROD` 参照へ集約 |
| `scripts` | 11 | CLI引数または環境変数を正本にし、既定値は最後に切替 |
| `.claude` | 3 | 自動化の固定URLを確認し、外部契約の有無で判断 |
| `lib` | 2 | build-time URLを先に切替。公開メモURL生成の互換性を確認 |
| `supabase` | 2 | migration内の保存済みURL/SQLを個別評価し、過去 migration は改変しない |
| `test` | 2 | production URL前提のfixtureを更新またはパラメータ化 |
| `integration_test` | 1 | production実接続テストを環境変数化 |
| `web` | 1 | preconnect、dns-prefetch、OGP preview Edge Function URLを切替 |
| ルート文書 | 1 | 運用上必要な箇所だけ更新 |

`docs` 内の191ファイルは履歴・schedule log・日報を多く含む。履歴を一括置換せず、
現行runbookや正本だけを更新する。

## 承認記録（Go/No-Go gate）

次の全項目が埋まるまで `domains create` 以降へ進まない。

| 項目 | 承認値 |
| --- | --- |
| 判断 | `未承認`（`Go` / `Defer` / `Reject`） |
| 承認者 | `未記入` |
| 承認日時（JST） | `未記入` |
| 月額上限 | `未記入`（推奨: USD 40 + 税 + 合意済み従量枠） |
| 利用 FQDN | `未記入`（subdomainのみ） |
| DNS provider / zone | `未記入` |
| DNS変更担当者 | `未記入` |
| Supabase組織の支払担当者 | `未記入` |
| OAuth provider変更担当者 | `未記入` |
| SAML利用 | `未確認`（利用中なら切替計画必須） |
| 実施日時 | `未記入` |
| rollback判断者 | `未記入` |

## DNS・SSL・activation 手順

ここでは `api.<approved-domain>` をプレースホルダーとして使う。実施時は、承認記録に
書かれた完全修飾ドメインへ置換する。

### Phase 0: 事前準備

1. Pro へのアップグレードと Custom Domain add-on の費用承認を記録する。
2. Supabase project の Owner/Admin権限、DNS zone編集権限、支払権限を別々に確認する。
3. Supabase CLI を実施時点の最新安定版へ更新する。
4. DNS TTLを低く設定できることを確認する。
5. production dashboard の Auth Site URL / Redirect URLs、Google OAuth、Twitter OAuth、
   SAML EntityID、外部 webhook/API consumer の現行値をエクスポートまたは画面記録する。
6. 既定URLと新URLの双方を受け入れられる外部連携は、activation前に両方を登録する。

### Phase 1: ドメイン登録とDNS検証

承認済み担当者が次を実行する。出力されるTXT値は実行時生成値を使い、文書へ固定しない。

```powershell
supabase domains create `
  --project-ref smmkxxavexumewbfaqpy `
  --custom-hostname api.<approved-domain>
```

DNS providerへ次を設定する。

| Type | Name | Value | TTL |
| --- | --- | --- | --- |
| CNAME | `api` | `smmkxxavexumewbfaqpy.supabase.co.` | 可能な範囲で低くする |
| TXT | `_acme-challenge.api` | `domains create` が返した値 | 可能な範囲で低くする |

provider が zone名を自動付加する場合、NameにFQDNを重ねて入力しない。設定後に
authoritative DNS と複数の外部 resolver から CNAME/TXT を確認する。

```powershell
supabase domains reverify --project-ref smmkxxavexumewbfaqpy
supabase domains get --project-ref smmkxxavexumewbfaqpy -o json
```

SSL発行には最大30分程度かかり得る。検証未完了のままactivationしない。

### Phase 2: activation前の互換設定

1. OAuth providerに次の両方の callback URLを許可する。
   - `https://smmkxxavexumewbfaqpy.supabase.co/auth/v1/callback`
   - `https://api.<approved-domain>/auth/v1/callback`
2. Supabase Authの Site URL / Redirect URLsには Firebase Hosting の実際のフロントエンド
   URLを維持する。これは API custom domain とは別である。
3. Twitter OAuthを利用する場合、cookieの互換性要件を満たすためフロントエンド側も
  同じ親ドメインを使えるかを先に確認する。満たせない場合はNo-Goとする。
4. SAMLを利用中の場合、EntityIDが変わることをIdP担当者と調整し、activation直前に
  新EntityIDへ切替できる保守時間を確保する。未調整ならNo-Goとする。
5. 外部 webhook/API consumerには新旧URLの並行期間とrollback URLを通知する。

### Phase 3: activation

変更開始を記録し、承認済み担当者が実行する。

```powershell
supabase domains activate --project-ref smmkxxavexumewbfaqpy
```

直後に以下を新旧両URLで確認する。

- `/auth/v1/health` 相当の認証到達性
- 代表的な read-only REST endpoint
- 認証必須 Edge Function と匿名公開 Edge Functionを各1本
- Storage public URL（利用中の場合）
- email/password sign-in、Google OAuth開始・callback・session保持
- public memo OGP preview
- GitHub Actions の production smoke

Authはactivation直後から custom domain を広告する。既定 project domain は引き続き
リクエストを処理するため、APIクライアントの一括切替はactivation条件ではない。

### Phase 4: 段階的なコード切替

1. GitHub secret `SUPABASE_URL_PROD` を custom domain へ変更する。
2. production Flutter buildを行い、認証・RLS・Realtime・Storage・Edge Functionsを確認する。
3. workflowの固定URLを `SUPABASE_URL_PROD` へ集約して小分けに移行する。
4. `web/index.html` の preconnect/dns-prefetch/OGP preview URLを切替える。
5. scripts、integration test、現行runbookを切替える。
6. 新URLのエラー率・latency・Auth callback失敗を24時間監視する。
7. 7日間の安定確認後も、Supabaseが既定URLを提供する限りrollback経路として記録を残す。

## ダウンタイムと対策

### 予定ダウンタイム

- API、REST、Edge Functions、Storage: **0分を目標**。activation後も既定URLが動作し、
  新旧を並行利用できるため。
- email/password Auth: **0分を目標**。ただしメール内リンクとcallbackを実機確認する。
- OAuth: 事前に新旧callbackを登録できれば **0分を目標**。登録漏れはログイン障害になる。
- SAML: EntityID変更があるため、IdPとの同時切替ができなければ停止が発生し得る。
- Twitter OAuth cookie: フロントエンドとAPIの親ドメイン構成次第で追加対応が必要。

### 中止条件

- DNS CNAME/TXTがauthoritative DNSで一致しない。
- SSL検証が完了しない、または証明書エラーがある。
- OAuth providerに新旧callbackを事前登録できない。
- SAML利用が未確認、またはIdP担当者と切替時刻を合意できない。
- 新URLで代表 smoke が失敗する。
- 費用上限、支払担当者、rollback判断者が未記入。

## Rollback

1. アプリ、GitHub secret、workflow、外部consumerのベースURLを
   `https://smmkxxavexumewbfaqpy.supabase.co` へ戻す。
2. Firebase Hosting の直前正常版を再deployする（frontend自体のドメインは変わらない）。
3. OAuth providerでは旧callbackを削除せず残しておき、旧経路でログインを確認する。
4. SAML利用時は旧EntityIDへ戻す手順をIdP担当者と同時実施する。
5. 既定URLで主要smokeが成功するまで custom domain を削除しない。
6. 復旧確認後、課金停止が必要で承認がある場合にのみ実行する。

```powershell
supabase domains delete --project-ref smmkxxavexumewbfaqpy
```

`domains delete` は destructive かつAuth/OAuth/SAMLへ影響するため、障害発生時の最初の操作に
しない。既定URLへの切戻しでサービスを復旧してから、別途承認を得て実行する。

## 実施チェックリスト

- [ ] 承認記録の全項目が記入済み
- [ ] Pro + Custom Domain の月額上限を承認済み
- [ ] 正確なFQDNとDNS変更担当者を確定
- [ ] 現行 Auth / OAuth / SAML / webhook 設定を保存
- [ ] 新旧OAuth callbackを事前登録
- [ ] CNAME/TXTを設定し、SSL検証完了
- [ ] activation前 smoke baselineを保存
- [ ] activation変更開始をIssueへ記録
- [ ] 新旧URLのpost-activation smoke成功
- [ ] GitHub secretから段階的に切替
- [ ] 24時間監視成功
- [ ] 7日間の安定確認完了
- [ ] 費用実績を請求画面で確認
- [ ] Issueの受け入れ条件と証跡を更新

## 公式資料

- [Supabase Custom Domains](https://supabase.com/docs/guides/platform/custom-domains)
- [Manage Custom Domain usage](https://supabase.com/docs/guides/platform/manage-your-usage/custom-domains)
- [Supabase Pricing](https://supabase.com/pricing)
- [Billing on Supabase](https://supabase.com/docs/guides/platform/billing-on-supabase)
- [Cost control](https://supabase.com/docs/guides/platform/cost-control)
