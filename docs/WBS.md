# 閾ｪ蛻・ｪ蠑丈ｼ夂､ｾ 髢狗匱 WBS (Work Breakdown Structure)

> **譛邨よ峩譁ｰ**: 2026-04-23 Codex (ノートコメント Notion風再利用Realtime)
> **蜿ら・**: 繧ｵ繧､繝井ｸ翫・ `/project-gantt` 繝壹・繧ｸ縺ｧ繝ｪ繧｢繝ｫ繧ｿ繧､繝遒ｺ隱榊庄閭ｽ  
> **DB**: `wbs_milestones` + `wbs_tasks` 繝・・繝悶Ν (migration 20260417180000 / 20260417190000 / 20260417200000)

## 収益化P0 現在地 (2026-08-19)

- ゴールは未達。完了条件は、知人ではない外部ユーザーの実決済、Stripe Payout、銀行口座への1円以上の着金を同じ証跡で確認すること。
- LP仮説A01-A10は各2案、合計20 armを実装・本番検証済み。2026-08-19のPIIなし本番集計は692 unique LP views、10 trials、1 save CTA、2 signup submits、0 verified signups。trial/view 1.45%、signup submit/view 0.29%、signup completion 0%で、現在の最狭ボトルネックは登録送信から認証完了への遷移。arm別の標本と登録完了が不足しているため、判定は全て`insufficient_data`のままとし、仮説を「勝ち」とは扱わない。
- 2026-08-05のSupabase Auth照合では新規auth records 3、confirmed 0、non-anonymous 0。計測欠損だけではなく、外部ユーザーが認証完了まで到達していないことを確認した。最新期間の認証完了は次回レポートで再照合する。
- X Hook Aの24時間結果は13 impressions、1 engagement、0 clicks、0 LP views、0 signups、0 payments。一方、`first_user_growth`計測URL全体では4 unique views、1 trial、0 signups。入口Hook改善とtrial後登録導線改善を別々に計測する。
- X Hook BはIssue [#4343](https://github.com/kanta13jp1/my_web_app/issues/4343) と候補ID `6203a344-55bd-44a0-b4ba-ab191f6fb9a2` まで準備済み。公開には所有者の明示承認が必要で、未承認のため未投稿。
- 2026-08-19実行のStripe Account Readiness workflowで、live mode、`details_submitted=true`、`charges_enabled=true`、`payouts_enabled=true`、未完了要件0を伏字済みJSONで確認した。決済・Payout基盤は外部購入者を受け入れ可能で、次の障害は外部ユーザーの登録完了と課金転換。
- 2026-07-29にHexCivの500円live決済、処理済み`checkout.session.completed`、ダウンロードURL発行2回を本番DBで確認した。ただし購入者は`user_profiles.is_admin=true`かつ`role=admin`のため自己購入であり、外部ユーザー売上・1人目獲得・銀行着金ゴールには数えない。決済/Webhook/商品配信経路の動作確認証跡としてのみ扱い、現時点の適格な外部決済額は0円。
- 2026-08-08の匿名本番ブラウザ実査では、静的SEOシェルからFlutter初回描画まで約20秒、本番`main.dart.js`は圧縮転送でも4,597,034 bytesだった。ルートLPの静的CTAは同一ページへ遷移して進行中の本体読込を再開前に破棄する構造だったため、`main.dart.js`の先読みと`history.replaceState`による無再読込handoffを追加した。
- 同実査で登録前trialの提案生成は成功したが、次の「無料で保存して始める」CTAは1280x720 viewportに対して`top=868px`で画面外だった。trial直後にCTAへ自動スクロールし、モバイルではキーボードを開かない修正を最優先の登録導線として維持する。
- trialで固定文を即時表示していた実装は、AI失敗時にも成功したように見えて登録を促す信頼上の欠陥だった。PR [#4599](https://github.com/kanta13jp1/my_web_app/pull/4599) を本番反映し、実AIのloading、成功、回数上限、接続失敗、再試行を分離した。成功時だけ保存CTAを表示して自動スクロールし、デスクトップ/390pxモバイルの本番QAまで完了した。
- 2026-08-19のSupabase認証設定監査では、Google provider、新規登録、Email providerは有効で、本番Site URL / Redirect URLsも正しかった。一方、custom SMTPは無効だった。登録送信2件・完了0件をMagic Linkコピーだけで改善する前提は棄却し、Google OAuthを主導線、Magic Linkを代替へ変更する。
- 認証handoffのPIIなし診断として、Magic Link試行、送信成功、失敗分類（形式、rate limit、配信設定、redirect、network、unknown）、Google OAuth開始、受信箱遷移を日次集計へ追加する。メールアドレス、生エラー本文、入力内容は保存しない。
- Google認証の往復でもtrial結果を失わないよう、AI提案をブラウザローカルに24時間だけ保留し、同じブラウザで認証済みユーザーが戻った場合にonboardingへ復元する。これは実装中で、本番デプロイと外部ユーザー1人のverified signupが確認できるまでは完了扱いにしない。
- 支援Checkoutの購入者分類を追加する。任意のログインJWTをサーバー側で検証し、`admin_self` / `authenticated_non_admin` / `anonymous_unclassified` をStripe metadataへ付与する。署名済みWebhookと`revenue.funnel_report`は管理者・匿名・旧形式の未分類決済を外部売上から除外し、PIIなしSQLでのみ集計する。
- クリティカルパス:
  1. Google OAuth主導線、Magic Link復旧UI、認証handoff診断を本番反映し、デスクトップ/モバイルで登録開始を確認
  2. 知人ではない外部ユーザー1人のGoogle verified signupとfirst actionをUTMで確認。Magic Linkはcustom SMTP設定後に別途配信確認
  3. 明示承認後にHook Bを1回だけ公開し、3h/24hの固定ファネルを計測
  4. X計測URLからsignupとfirst actionまで到達した、ログイン済み非管理者のFounding Supporter 100円決済とpaid Webhookを確認。匿名・自己購入・未分類の決済は除外する
  5. Stripe Payoutと伏字済み銀行明細の1円以上着金を照合
- 直近P0タスク:
  1. `Codex`: Google優先登録、Magic Link復旧、OAuth trial復元、PIIなし認証handoffレポートをPR化し、CIと本番QAを通す。
  2. `Codex`: デプロイ後に手動workflowを再実行し、Google OAuth開始、verified signup、first actionを同じ観測期間で確認する。個人情報やraw eventを成果物へ含めない。
  3. `所有者`: custom SMTPを利用する場合は、送信ドメインを検証したメール事業者の認証情報をSupabaseへ設定する。外部サービス契約や課金を伴うため、Codexは明示承認なしに変更しない。
  4. `所有者`: 本番QA後、Hook Bの公開を明示承認する。公開後3時間/24時間のUTM流入を固定観測し、無関係なトレンド便乗や自動DMは行わない。
  5. `外部ユーザー`: 知人ではない利用者が登録、first action、100円支援決済を完了する。Stripeの`authenticated_non_admin`分類とpaid webhookが受入証跡。
  6. `Stripe/銀行`: 適格決済を含むpaid payoutと銀行明細の1円以上着金を照合する。pending/in transitは完了扱いにしない。
- 禁止事項: 自己決済や知人決済を獲得証跡に数えない。自動DM・自動follow・無関係なトレンド便乗・架空ニュース・承認前X投稿を行わない。
- WBS反映: migration `20260731120000_wbs_revenue_current_gate.sql` / `20260805140000_wbs_lp_trial_signup_conversion_gate.sql` / `20260819193000_landing_auth_funnel_diagnostics.sql` / `20260819194000_wbs_google_first_registration_gate.sql`。Stripe readiness、支援購入者分類、Hook B計測、trial後登録導線、Google優先認証handoffを銀行着金タスクへ接続し、重複Issueを増やさない。

## LP 10仮説の検証台帳 (2026-08-19)

- 判定ルール: widget/回帰テスト通過は「実装検証済み」、本番のcontrol/treatment差は「統計判定」。登録完了0の現状では、見かけのクリック差だけで勝者を決めない。
- 共通ファネル: 692 views -> 10 trials -> 1 save CTA -> 2 signup submits -> 0 verified signups。first action以降はverified signupが0のため未到達。

| ID | 仮説 | 実装検証 | 本番判定 / 次の確認 |
|---|---|---|---|
| H01 | 成果を先に伝えるヒーロー | treatment/controlとCTA計測をテスト済み | `insufficient_data`; hero CTAからverified signupまで比較 |
| H02 | 目的別パーソナライズ | 仕事・お金・学習の切替とtrial計測をテスト済み | `insufficient_data`; trial開始率と登録完了率を比較 |
| H03 | 登録前の価値体験 | 登録前trial、X深リンク、SEOシェルからの無再読込handoffをデスクトップ/モバイルでテスト済み | 10 trialsを確認、ただし登録完了0; 正直なAI状態表示とtrial->signupを最優先改善 |
| H04 | Googleを主導線、メールを代替にする | Google優先CTA、Magic Link失敗時の画面内復旧、OAuth trial復元、PIIなし失敗分類を実装対象に追加 | 2 submits / 0 completes; 旧期間はcustom SMTP未設定の交絡があるため勝敗判定せず、デプロイ後のverified signupで再評価 |
| H05 | 料金リスクを先回りして解消 | カード不要・無料範囲の表示差をテスト済み | `insufficient_data`; verified signupへの影響を比較 |
| H06 | 具体的な利用結果を見せる | product proofの表示差をテスト済み | `insufficient_data`; trial開始と登録完了を比較 |
| H07 | 実数の社会的証明 | 公開集計のみの匿名安全な表示をテスト済み | `insufficient_data`; signup submitではなくcompleteで評価 |
| H08 | プライバシー不安を解消 | assurance表示とcontrol差をテスト済み | `insufficient_data`; primary metricはsignup completion |
| H09 | モバイル固定CTA | 390px幅の表示・保存遷移・mobile metricをテスト済み | `insufficient_data`; mobile signup completionを比較 |
| H10 | 登録後に続きが残る価値 | trial結果と継続価値の表示差をテスト済み | `insufficient_data`; trial->verified signupを比較 |

## 収益化P0メモ (2026-06-27)

- セッションゴール: Stripe等で決済を成立させるだけではなく、実際の銀行口座へ1円以上の入金が確認できるところまで追う。
- DB反映: migration `20260627093000_wbs_revenue_first_monetization.sql` で `first-yen-revenue` milestone と収益化P0タスク5件を追加。
- 最優先タスク:
  1. `[追加要望][収益化P0] Stripe本番・銀行入金レディネス確認`
  2. `[追加要望][収益化P0] Stripe本人確認・入金停止解除`
  3. `[追加要望][収益化P0] Live Checkout + Webhook 証跡を本番で取得`
  4. `[追加要望][収益化P0] Founding Supporter 有料CTAを公開`
  5. `[追加要望][収益化P0] 初回購入者獲得スプリント`
  6. `[追加要望][収益化P0] 銀行口座への1円以上入金を確認`
- 1人目ユーザー獲得P0:
  1. `[追加要望][収益化P0][1人目獲得] 最初の対象ユーザー像と10名リストを作る`
  2. `[追加要望][収益化P0][1人目獲得] 1対1アウトリーチ10件を実施`
  3. `[追加要望][収益化P0][1人目獲得] 公開投稿1本と導線クリックを確認`
  4. `[追加要望][収益化P0][1人目獲得] 初回ユーザーの利用証跡とヒアリングを取得`
  5. `[追加要望][収益化P0][1人目獲得] Stripe解除後に初回支援決済へ転換`
- Xインプレッション獲得P0（知人・接点あり禁止）:
  1. `[追加要望][収益化P0][X集客] プロフィールを1人目ユーザー獲得用に改修`
  2. `[追加要望][収益化P0][X集客] 固定ポストをサイト導線に差し替え`
  3. `[追加要望][収益化P0][X集客] 7日間・1日5投稿のインプレッション実験`
  4. `[追加要望][収益化P0][X集客] 大きめアカウントへの有益リプライ30件`
  5. `[追加要望][収益化P0][X集客] Xアナリティクスで勝ち投稿を増幅`
  6. `[追加要望][収益化P0][X集客] X経由の1人利用を確認`
- 10Kインプレッション狙いP0（ユーザーの勝ち投稿パターン反映）:
  1. `[追加要望][収益化P0][X集客][10K] Xトレンド連動デイリーブリーフィング生成を本番化`
  2. `[追加要望][収益化P0][X集客][10K] 10Kインプレッション狙いのブリーフィング投稿を7日実行`
  3. `[追加要望][収益化P0][X集客][10K] 勝ち投稿から1人目ユーザー導線へ転換`
  4. `[追加要望][収益化P0][X集客][10K] X投稿メトリクス監視・A/B自動改善ループを本番化`
- 実装側の確認結果: `subscription_billing_page.dart`、`billing_service.dart`、`schedule-hub`のbilling actions、`stripe-webhook`、billing tablesは存在する。さらにログイン不要のFounding Supporter一回払いCheckoutと、`hub_data.source = stripe_supporter_payment`の証跡記録を追加。Supabase Edge FunctionsとFirebase Hostingへの公開は完了し、Supabase `STRIPE_SECRET_KEY` をlive keyへ更新後、100円Checkoutが `cs_live...` を返すことを確認済み。`STRIPE_WEBHOOK_SECRET` もlive endpointの `whsec...` に更新済み。ただしStripeのアカウントステータスで「担当者の本人確認書類を提出する」が審査中/入金停止リスクあり。Stripeダッシュボードの売上/JPY残高/顧客/サブスクは0。残る焦点はStripe本人確認完了、初回実決済、Webhook証跡、銀行入金証跡。
- 検証ゲート: 最新の機械判定ステージは `live_checkout_ready_for_real_payment`。`Stripe本人確認・入金停止解除` を独立P0として追加済み。Stripeアカウントステータスの本人確認タスクが`完了`になり、入金停止が解消されるまでは宣伝・実決済を開始しない。実決済後は `--require-webhook`、銀行着金後は redacted bank evidence JSON + `--require-bank` を通してからゴール達成扱いにする。
- 初回購入者獲得: Stripe本人確認完了後だけ `docs/marketing/first-revenue-outreach.md` のFounding Supporter文面を使う。入金停止中は宣伝しない。Live環境での自己決済テストは避け、実在の支援者/顧客からの支払いとして扱う。
- 1人目ユーザー獲得: 支払い依頼はStripe本人確認完了まで止めるが、無料利用/フィードバック依頼は今すぐ開始する。`docs/marketing/first-user-acquisition-sprint.md` を使い、まず10名の具体的な対象者へ1対1で依頼する。匿名PVや自分のテストは「1人獲得」に数えない。
- X集客: ユーザー方針により知人・接点ありの相手には頼らない。`https://x.com/kanta13jp1` のプロフィール、固定ポスト、7日間投稿、30件有益リプライ、Xアナリティクス増幅で1人目を取りに行く。実行文書は `docs/marketing/x-impression-growth-sprint.md`。
- AIシェア改善: `UniversalXShareService` とAIシェアダイアログをX集客用に更新。共有URLへ `utm_campaign=first_user_growth` を付け、固定/課題/機能/質問/返信/ブリーフィングプリセットを追加し、OpenAI画像生成が課金上限で失敗してもテキスト投稿を続行できるようにした。X APIが402 credits不足で直接投稿に失敗した場合も投稿文をコピーしてX投稿画面へフォールバックする。2026-06-27追記: Xトレンド取得、デイリーブリーフィング型スレッド、URLを返信へ逃がす投稿、10Kインプレッション計測タスクを追加。`growth-hub`、`viral-video-ad-generator`、Firebase Hostingへ反映済み。さらにライブAIシェアで `Unknown action: x.trends` が出たため `growth-hub` を再デプロイし、WBS上のトレンド連動ブリーフィング本番化タスクを98%へ更新。2026-06-27追加: `x.metrics_collect` / `x.performance_context` でX投稿と返信のメトリクスを収集し、`x_post_log.latest_metrics` と `x_post_metric_snapshot` に保存、勝ちパターンを次回AIシェア生成プロンプトへ戻すA/B改善ループを追加。GitHub Actions `x-post-metrics-optimizer.yml` で3時間ごとに監視する。WBS登録: migration `20260627113000_wbs_ai_share_x_growth_mode.sql` / `20260627162000_wbs_x_trend_briefing_10k_p0.sql` / `20260627164000_wbs_x_trends_action_hotfix.sql` / `20260627173500_wbs_x_post_metrics_ab_optimizer.sql`。
- X流入CVR改善: `utm_source=x&utm_campaign=first_user_growth` でランディングに来た人だけに、5分トライアル誘導と「A 要約 / B メモ / C 後で探す」の1クリックフィードバックCTAを表示する。クリックは `app_analytics.source_details` の `x_first_user_*` シグナルとして記録し、Xで一言返すintentも用意する。目的はインプレッションを匿名PVで終わらせず、1人目ユーザー証跡へつなぐこと。WBS登録: migration `20260627170000_wbs_x_first_user_feedback_capture.sql`。
- X施策の収益接続: 2026-06-27追記。X投稿A/B改善で得た `utm_*` / `experiment_key` / `variant` / `source_log_id` をFounding Supporter 100円Checkoutへ引き継ぎ、Stripe `checkout.session.completed` Webhookを `hub_data.source = stripe_supporter_payment` として保存する。`growth-hub` に `revenue.funnel_report` を追加し、インプレッション勝者と売上勝者を分けて確認できるようにした。証跡確認SQL: `supabase/sql/first_supporter_webhook_evidence.sql`。WBS登録: migration `20260627184500_wbs_revenue_funnel_attribution.sql`。
- Obsidian/記憶連携確認: `memory/` と `docs/` を `scripts/knowledge_vault_lint.py` で確認し、2026-06-27時点のHealth Scoreは96/100。構造は十分使えているが、直近の収益化P0（Stripe本番、X集客、Hedra/ElevenLabs動画、銀行入金証跡）がまだObsidian/memoryへ同期されていなかったため、`memory/vault/revenue_first_growth_loop_20260627.md` を追加。WBS登録: migration `20260627121500_wbs_revenue_obsidian_media_loop.sql`。
- Hedra/ElevenLabs活用: `viral-video-ad-generator` にElevenLabs音声生成→Hedra音声アセットupload→Hedra presenter video生成の経路を追加。ElevenLabs/Hedraが失敗した場合は既存Hedra TTSまたはテキスト投稿へフォールバックする。本番でElevenLabs音声アセット作成とHedra動画生成完了まで確認済み（generation `b68583c2-7ba4-4367-a06d-6d12b3e8e1c4`）。さらにHedraの一時署名URLをSupabase Storage公開URLへコピーするようにして、Obsidian/WBS/X投稿で後から追える証跡にした。ライブUIから開始した `feature_highlight` のHedraジョブ `e8fe90b2-c1f7-4d43-bdd7-38b4cbd6a250` もStorage保存済みMP4としてHTTP 200を確認。2026-06-27追記: `model missing not valid for generation type text_to_speech` 対策として、Hedra `/models` からTTS `model_id` を自動解決し、ElevenLabs TTSリクエストを最小構成化した本番関数をデプロイ済み。AI秘書サイトツアー動画 `5333ecf8-6a39-49d3-9f9b-b5c1aa63e812` もStorage保存済みMP4としてHTTP 200を確認: `https://smmkxxavexumewbfaqpy.supabase.co/storage/v1/object/public/viral-ad-videos/hedra/2026-06-27/5333ecf8-6a39-49d3-9f9b-b5c1aa63e812-ai_secretary_site_tour-ja.mp4`。残作業はこの動画をX投稿へ使って1人目ユーザー獲得の実測へつなげること。
- OpenAI API課金復旧: AI秘書動画の高品質化で使う image-gen2/GPT Image は、ChatGPT課金ではなくOpenAI Platform APIクレジットが必要。`Billing hard limit has been reached` はAPI課金上限/残高不足を示す。2026-06-27時点でOpenAI Platform Billingに約15 USDのクレジット反映を確認し、AIシェア画像生成が公開Storage URLを返すところまで回復。アプリ側は `media-hub` を更新し、`openai_billing_required` と請求URLを返すようにし、DALL-E fallbackへ古い `style` / `response_format` パラメータを送らない本番関数をデプロイ済み。WBS登録: migration `20260627130000_wbs_revenue_ai_secretary_openai_billing.sql`。
- 詳細レビュー: `docs/MONETIZATION_REVENUE_FIRST_REVIEW.md`

## Codex 蠑輔″邯吶℃繝｡繝｢ (2026-04-21)

- Claude quota 蛻ｶ髯蝉ｸｭ縺ｮ荳譎ょｯｾ蠢懊→縺励※縲・*螳滄圀縺ｫ逹謇区ｸ医∩縺ｮ繧ｿ繧ｹ繧ｯ縺ｮ縺ｿ** `Codex` 諡・ｽ薙↓螟画峩縲・
- Codex 諡・ｽ灘ｯｾ雎｡:
  `DESIGN.md蜈ｨ繝壹・繧ｸ貅匁侠 60%驕疲・` / `繝｢繝舌う繝ｫ繝ｬ繧ｹ繝昴Φ繧ｷ繝門ｮ悟・蟇ｾ蠢彖 /
  `遶ｶ蜷域ｯ碑ｼ・・繝ｼ繧ｸ譛譁ｰ蛹冒 / `Web繝代ヵ繧ｩ繝ｼ繝槭Φ繧ｹ譛驕ｩ蛹・(LCP < 2.5s)` /
  `BYPASS_RULES secret險ｭ螳啻 / `繧ｪ繝ｳ繝懊・繝・ぅ繝ｳ繧ｰ譛驕ｩ蛹冒 / `邏ｹ莉九・繝ｭ繧ｰ繝ｩ繝螳溯｣・ /
  `E2E繝・せ繝域紛蛯・(Playwright)` / `繧ｨ繝ｩ繝ｼ逶｣隕門ｼｷ蛹・(Sentry騾｣謳ｺ)` /
  `逕ｻ蜒冗函謌千ｵｱ蜷・ / `繝槭Ν繝√Δ繝ｼ繝繝ｫAI` / `AI螟ｧ蟄ｦ 100遉ｾ驕疲・` / `SEO謾ｹ蝟・(sitemap繝ｻmeta tags)` /
  `繧ｿ繧､繝昴げ繝ｩ繝輔ぅ邨ｱ荳 (line-height 1.7+)` / `FSRS蟄ｦ鄙偵す繧ｹ繝・Β螳悟・螳溯｣・
- 驕主悉縺ｮ縲梧悴螳御ｺ・ち繧ｹ繧ｯ蜈ｨ莉ｶ繧・Codex 縺ｫ髮・ｴ・肴婿驥昴・驕主臆縺ｪ縺溘ａ縲∝ｾ檎ｶ・migration 縺ｧ諡・ｽ薙ｒ蜷・lane owner 縺ｫ謌ｻ縺吶・

## Codex 蠑輔″邯吶℃繝｡繝｢ (2026-04-22)

- 莉雁屓螳滄圀縺ｫ逹謇九＠縺溘ち繧ｹ繧ｯ縺ｮ縺ｿ Codex 諡・ｽ薙↓邯ｭ謖・
  `DESIGN.md蜈ｨ繝壹・繧ｸ貅匁侠 60%驕疲・` / `繝｢繝舌う繝ｫ繝ｬ繧ｹ繝昴Φ繧ｷ繝門ｮ悟・蟇ｾ蠢彖 / `邨ｱ荳蝨ｰ譁ｹ驕ｸ AI閾ｪ蜍必PI譖ｴ譁ｰ`
- 螳溯｣・・螳ｹ: `2027 邨ｱ荳蝨ｰ譁ｹ驕ｸ 700蠢・＃邂｡逅・ｮ､` 縺ｫ蜈ｨ蝗ｽKPI繝槭ャ繝励ｒ霑ｽ蜉縺励√Δ繝舌う繝ｫ縺ｯ邵ｦ遨阪∩縲√ョ繧ｹ繧ｯ繝医ャ繝励・蝨ｰ蝗ｳ+隧ｳ邏ｰ繝代ロ繝ｫ縺ｮ讓ｪ荳ｦ縺ｳ縺ｧ陦ｨ遉ｺ縲・
- WBS DB 蜿肴丐: migration `20260422083000_wbs_codex_election_kpi_map.sql` 縺ｧ owner_instance=Codex縲・ｲ謐励ｒ DESIGN 66% / 繝｢繝舌う繝ｫ 71% 縺ｫ譖ｴ譁ｰ縲・
- 霑ｽ蜉謾ｹ蝟・ 譌･譛ｬ蝨ｰ蝗ｳUI縺ｫ豬ｷ髱｢閭梧勹縲∝慍蝓溘Λ繝吶Ν縲・∈謚樔ｸｭ逵碁｣繝舌ャ繧ｸ縲・㍾轤ｹ蠎ｦ繝舌・繧定ｿｽ蜉縲Ｎigration `20260422093000_wbs_codex_election_map_ui_polish.sql` 縺ｧ DESIGN 67% / 繝｢繝舌う繝ｫ 72% 縺ｫ譖ｴ譁ｰ縲・
- AI騾｣謳ｺ蠑ｷ蛹・ `local-election-intelligence` 縺ｮ螳滓・繝・・繧ｿ繧偵Θ繝ｼ繧ｶ繝ｼ蜈･蜉帙↑縺励〒逵碁｣KPI縺ｸ蜿肴丐縲ら樟閨ｷ莠ｺ謨ｰ縲∫岼讓呎刀遶区焚縲∽ｺ亥ｮ夐∈謖呎焚縲∝・隱肴悄髯舌、I閾ｪ蜍墓峩譁ｰ繝｡繝｢繧剃ｿ晏ｭ倥☆繧九Ｎigration `20260422100000_wbs_codex_election_ai_auto_sync.sql` 縺ｧ AI邨ｱ蜷磯ｲ謐励ｒ險倬鹸縲・
- 蜈･蜉婉I謦､蜴ｻ: 逵碁｣KPI邱ｨ髮・√ユ繝ｳ繝励Ξ繝ｼ繝亥・驕ｩ逕ｨ縲∵怦谺｡陦ｨ縺九ｉ縺ｮKPI邱ｨ髮・∵兜遞ｿ譛ｬ譁・ｷｨ髮・ｰ守ｷ壹ｒ螟悶＠縲、I閾ｪ蜍墓峩譁ｰ蟆ら畑縺ｮ隱ｭ縺ｿ蜿悶ｊ荳ｭ蠢ザI縺ｸ螟画峩縲Ｎigration `20260422103000_wbs_codex_election_readonly_ai_sync.sql` 縺ｧ蜿肴丐縲・
- 繧｢繧ｳ繝ｼ繝・ぅ繧ｪ繝ｳUI: 逵碁｣荳隕ｧ繧貞慍蝓溷挨縲∬ｭｰ蜩｡蜷咲ｰｿ繧堤恁蛻･縲∝・蠑上た繝ｼ繧ｹ繧呈釜繧顔糞縺ｿ蜿ｯ閭ｽ縺ｫ縺励・哩縺倥◆迥ｶ諷九〒繧ゆｸｻ隕゜PI繧帝寔險医メ繝・・縺ｧ遒ｺ隱阪〒縺阪ｋ繧医≧謾ｹ蝟・Ｎigration `20260422110000_wbs_codex_election_accordion_ui.sql` 縺ｧ蜿肴丐縲・
- 遶区・豈碑ｼ・UX謾ｹ蝟・ `local-election-intelligence` 縺檎ｫ区・豌台ｸｻ蜈壼・蠑上瑚・豐ｻ菴楢ｭｰ蜩｡縲肴ュ蝣ｱ縺九ｉ逵悟挨蝨ｰ譁ｹ隴ｰ蜩｡謨ｰ繧定・蜍暮寔險医＠縲∫ｵｱ荳蝨ｰ譁ｹ驕ｸ700蠢・＃邂｡逅・ｮ､縺ｫ繝吶Φ繝√・繝ｼ繧ｯ縲∫恁蛻･繧ｫ繝ｼ繝峨∝慍蝗ｳ隧ｳ邏ｰ縺ｨ縺励※蜿肴丐縲Ｎigration `20260422113000_wbs_codex_election_cdp_benchmark.sql` 縺ｧ蜿肴丐縲・
- 逵碁｣KPI X蜈ｱ譛・ 逵碁｣KPI縺ｮ蜈ｱ譛画枚逕滓・縺ｨ蜈ｬ髢偽RL蟆守ｷ壹ｒ霑ｽ蜉縲よ怙邨６I縺ｯ荳玖ｨ倥・荳諡ｬ蜈ｱ譛峨ヮ繝ｼ繝域婿蠑上∈邨ｱ蜷医Ｎigration `20260422115000_wbs_codex_election_prefecture_x_share.sql` 縺ｧ蜿肴丐縲・
- 蜈ｬ髢偽RL/荳諡ｬ蜈ｱ譛峨ヮ繝ｼ繝・ `/local-election-700` 繧呈悴繝ｭ繧ｰ繧､繝ｳ譎ゅｂ蜈ｬ髢九ン繝･繝ｼ縺ｨ縺励※逶ｴ謗･蜿ら・縺ｧ縺阪ｋ繧医≧縺ｫ縺励々蜈ｱ譛峨・逵碁｣蛻･縺ｧ縺ｯ縺ｪ縺丞・逵碁｣KPI繧・縺､縺ｮ蜈ｱ譛峨ヮ繝ｼ繝医↓縺ｾ縺ｨ繧√※繝ｪ繝ｳ繧ｯ蜈ｱ譛峨☆繧句ｰ守ｷ壹∈螟画峩縲Ｎigration `20260422123000_wbs_codex_election_public_bulk_share.sql` 縺ｧ蜿肴丐縲・
- KGI/CSF/KPI險ｭ險・ 蜷・恁騾｣縺ｮKGI繧偵檎ｵｱ荳蝨ｰ譁ｹ驕ｸ蠕後・蝨ｰ譁ｹ隴ｰ蜩｡蛻ｰ驕疲焚縲阪→縺励※險ｭ螳壹＠縲゜GI驕疲・縺ｮCSF縺斐→縺ｫ謨ｰ蛟､KPI繝ｻ騾ｲ謐励・谿区焚繧定・蜍慕ｮ怜・縲ら判髱｢繧ｫ繝ｼ繝峨→荳諡ｬ蜈ｱ譛峨ヮ繝ｼ繝医∈蜿肴丐縲Ｎigration `20260422124500_wbs_codex_election_kgi_csf_kpi.sql` 縺ｧ蜿肴丐縲・
- 蜈ｨ菴適GI/CSF/KPI陦ｨ遉ｺ蝓ｺ逶､: KPI陦ｨ遉ｺ繧貞・騾壹・KGI/CSF/KPI繝代ロ繝ｫ縺ｫ蟇・○縲√・繝ｼ繝縲∝倶ｺｺ繝繝・す繝･繝懊・繝峨∬ｲ｡蜍吶，MO縲√ヰ繧､繝ｩ繝ｫ謖・ｨ吶∫ｵｱ荳蝨ｰ譁ｹ驕ｸ繝√Ε繝ｼ繝医∈菴ｵ險倥ょ嵜豌第ｰ台ｸｻ蜈壼慍譁ｹ隴ｰ蜩｡髮・ｨ域ｩ溯・縺ｯ谿句ｭ倥ユ繧ｹ繝医〒菫晁ｭｷ縲Ｎigration `20260422131000_wbs_codex_global_kgi_csf_kpi.sql` 縺ｧ蜿肴丐縲・
- 邨ｱ荳蝨ｰ譁ｹ驕ｸ 逵碁｣蛻･迴ｾ螳溽岼讓吝・隱ｿ謨ｴ: 逵碁｣蛻･KGI/KPI縺ｮ迴ｾ閨ｷ邯ｭ謖∫岼讓吶ｒ螳滄圀縺ｮ迴ｾ閨ｷ謨ｰ縺ｫ蜷医ｏ縺帙∵眠莠ｺ蠖馴∈逶ｮ讓吶・迴ｾ閨ｷ謨ｰ繧貞渕貅悶↓蜈ｨ菴・00莠ｺ蛻ｰ驕斐∈陬懈ｭ｣縲ら樟閨ｷ0逵後・莠亥ｮ夐∈謖吶ｄ蛟呵｣懃｢ｺ隱阪′縺ゅｋ蝣ｴ蜷医・縺ｿ蟆上＆縺ｪ雜ｳ蝣ｴ逶ｮ讓吶↓逡吶ａ繧九Ｎigration `20260422195000_wbs_codex_election_realistic_targets.sql` 縺ｧ蜿肴丐縲・
- 邨ｱ荳蝨ｰ譁ｹ驕ｸ 謫∫ｫ狗岼讓・蠖馴∈邇⑫PI隱ｿ謨ｴ: 蠖馴∈邇・0%繧貞燕謠舌↓縲∵眠莠ｺ謫∫ｫ狗岼讓吶ｒ譁ｰ莠ｺ蠖馴∈逶ｮ讓吶・1.25蛟阪∈邨ｱ荳縲ゅヰ繝・メKPI譖ｴ譁ｰ譎ゅ↓迴ｾ迥ｶ蠖馴∈邇・ｒ邂怜・縺励∝慍蝗ｳ隧ｳ邏ｰ縲゜GI/CSF/KPI縲∝・譛峨ヮ繝ｼ繝医∈陦ｨ遉ｺ縲Ｎigration `20260422200000_wbs_codex_election_candidate_win_rate.sql` 縺ｧ蜿肴丐縲・
- 逵碁｣蠖ｹ蜩｡陦ｨ遉ｺ: 逵碁｣莉｣陦ｨ繝ｻ逵碁｣蟷ｹ莠矩聞繝ｻ蜃ｺ蜈ｸURL繧堤恁騾｣繧ｫ繝ｼ繝峨→蜈ｱ譛峨Γ繧ｿ繝・・繧ｿ縺ｸ霑ｽ蜉縲ょ・蠑冗｢ｺ隱阪〒縺阪◆逵後°繧牙・譛溷､繧貞・繧後∵悴遒ｺ隱咲恁縺ｯ蜈ｬ蠑乗悴遒ｺ隱阪→縺励※陦ｨ遉ｺ縲Ｎigration `20260422133000_wbs_codex_election_prefecture_officers.sql` 縺ｧ蜿肴丐縲・
- 蝨ｰ譁ｹ隴ｰ蜩｡髮・ｨ医ヮ繝ｼ繝亥喧蟆守ｷ・ `蝗ｽ豌第ｰ台ｸｻ蜈・蝨ｰ譁ｹ隴ｰ蜩｡髮・ｨ・ 縺ｮ譌｢蟄倥ヮ繝ｼ繝育函謌先ｩ溯・繧堤判髱｢繝懊ち繝ｳ縺九ｉ逶ｴ謗･螳溯｡後〒縺阪ｋ繧医≧縺ｫ縺励∝・逵碁｣KPI繝弱・繝医→繝ｪ繝ｳ繧ｯ繧ｳ繝斐・蟆守ｷ壹ｒ蛻・屬縲Ｎigration `20260422141000_wbs_codex_election_snapshot_note_button.sql` 縺ｧ蜿肴丐縲・
- 雉・肇邂｡逅・驫陦靴SV蜿門ｾ玲隼蝟・ `雉・肇邂｡逅・(MoneyForward蟇ｾ謚・` 繧剃ｻ雁屓螳滄圀縺ｫ逹謇九☆繧狗ｯ・峇縺縺舛odex縺ｸ蠑輔″邯吶℃縲・oogle繧ｷ繝ｼ繝・SV蜿門ｾ励ｒ蜈ｱ騾壼喧縺励∽ｸ我ｺ穂ｽ丞暑/縺倥・繧馴橿陦後・蜿門ｾ怜､ｱ謨励ｒ譏守､ｺ縲√・繧ｿ繝ｳ蛻励ｒ繝｢繝舌う繝ｫ縺ｧ繧よ釜繧願ｿ斐○繧偽I縺ｫ謾ｹ蝟・Ｎigration `20260422143000_wbs_codex_asset_bank_csv_import.sql` 縺ｧ蜿肴丐縲・

- 蜈ｨ讖溯・AI謌ｦ逡･繝｢繝九ち繝ｪ繝ｳ繧ｰ蝓ｺ逶､: HomeToolCatalog 蜈ｨ讖溯・繧貞ｯｾ雎｡縺ｫ縲、I蛻・梵縲゜GI縲゜GI驕疲・縺ｮCSF縲，SF繝吶・繧ｹ縺ｮ謨ｰ蛟､KPI縲∝ｮ壽悄繝｢繝九ち繝ｪ繝ｳ繧ｰ縲∵隼蝟・く繝･繝ｼ繧定・蜍慕函謌舌☆繧九・繝ｼ繝讓ｪ譁ｭ繝代ロ繝ｫ繧定ｿｽ蜉縲・igration `20260422150000_wbs_codex_feature_strategy_monitor.sql` 縺ｧ蜿肴丐縲・
- 蜈ｨ讖溯・AI謌ｦ逡･繝ｬ繝薙Η繝ｼ螳蘗I騾｣謳ｺ: 蜈ｨ讖溯・AI謌ｦ逡･繝｢繝九ち繝ｪ繝ｳ繧ｰ邨先棡繧・`ai-hub provider.chat` 縺ｫ貂｡縺励∫樟迥ｶ蛻・梵縲・㍾隕，SF縲∵ｬ｡蝗樊隼蝟・い繧ｯ繧ｷ繝ｧ繝ｳ繧但I繝ｬ繝薙Η繝ｼ縺ｨ縺励※陦ｨ遉ｺ縲・I螟ｱ謨玲凾縺ｯ繝ｭ繝ｼ繧ｫ繝ｫKPI蛻・梵縺ｸ繝輔か繝ｼ繝ｫ繝舌ャ繧ｯ縲・igration `20260422153000_wbs_codex_feature_strategy_ai_review.sql` 縺ｧ蜿肴丐縲・
- 雉・肇邂｡逅・豬ｪ雋ｻ謚大宛AI繝医Ξ繝ｼ繝九Φ繧ｰ: 雉・肇邂｡逅・判髱｢縺ｫ縲梧ｵｪ雋ｻ縺励↑縺・％縺ｨ縺ｯ閭ｽ蜉帙ｒ鬮倥ａ繧玖ｨ鍋ｷｴ縲阪→縺・≧KGI/CSF/KPI繝代ロ繝ｫ繧定ｿｽ蜉縺励∵髪蜃ｺ繝ｻ豬ｪ雋ｻ繧ｫ繝・ざ繝ｪ繝ｻ蛟滄≡繝ｭ繝・け繝繧ｦ繝ｳ譌･隱ｲ縺九ｉKPI繧定・蜍慕ｮ怜・縲Ａai-hub provider.chat`縺ｧ迴ｾ迥ｶ蛻・梵縺ｨ谺｡繧｢繧ｯ繧ｷ繝ｧ繝ｳ繧堤函謌舌＠縲、I螟ｱ謨玲凾縺ｯ繝ｭ繝ｼ繧ｫ繝ｫKPI繧ｨ繝ｳ繧ｸ繝ｳ縺ｫ繝輔か繝ｼ繝ｫ繝舌ャ繧ｯ縲Ｎigration `20260422160000_wbs_codex_asset_waste_training_ai.sql` 縺ｧ蜿肴丐縲・
- 繝ｩ繧､繝墓ｵｪ雋ｻ繧ｼ繝ｭ蜿ｸ莉､蝪・+ AI謚ｽ雎｡蛹・ 鬘樔ｼｼ縺励※縺・◆ `ai-hub provider.chat` 蜻ｼ縺ｳ蜃ｺ縺励ｒ `AiHubChatService` 縺ｫ蜈ｱ騾壼喧縺励√・繝ｼ繝縺ｫ譎る俣繝ｻ縺企≡繝ｻ蛛･蠎ｷ繝ｻ菴灘鴨繝ｻ遏･閭ｽ繝ｻ髮・ｸｭ蜉帙・豬ｪ雋ｻ繧貞酔縺婁GI/CSF/KPI縺ｧ逶｣隕悶☆繧九後Λ繧､繝墓ｵｪ雋ｻ繧ｼ繝ｭ蜿ｸ莉､蝪斐阪ｒ霑ｽ蜉縲・I縺檎樟迥ｶ蛻・梵繝ｻ譛驥崎ｦ，SF繝ｻ谺｡繧｢繧ｯ繧ｷ繝ｧ繝ｳ繝ｻ谺｡蝗槭Δ繝九ち繝ｪ繝ｳ繧ｰ隕ｳ轤ｹ繧堤函謌舌＠縲∝､ｱ謨玲凾縺ｯ繝ｭ繝ｼ繧ｫ繝ｫKPI繧ｨ繝ｳ繧ｸ繝ｳ縺ｸ繝輔か繝ｼ繝ｫ繝舌ャ繧ｯ縲Ｎigration `20260422170000_wbs_codex_life_waste_command_center.sql` 縺ｧ蜿肴丐縲・
- 繝ｩ繧､繝戊ｳ・悽譌･谺｡繧ｹ繝翫ャ繝励す繝ｧ繝・ヨ + 邯咏ｶ壻ｽ惹ｸ九い繝ｩ繝ｼ繝・ 譎る俣繝ｻ縺企≡繝ｻ蛛･蠎ｷ繝ｻ菴灘鴨繝ｻ遏･閭ｽ繝ｻ髮・ｸｭ蜉帙・繝ｩ繧､繝戊ｳ・悽繧ｹ繧ｳ繧｢繧・0譌･蛻・Ο繝ｼ繧ｫ繝ｫ菫晏ｭ倥＠縲・譌･莉･荳・0%譛ｪ貅縺檎ｶ壹￥雉・悽繧偵・繝ｼ繝縺ｧ繧｢繝ｩ繝ｼ繝郁｡ｨ遉ｺ縲Ｎigration `20260422190000_wbs_codex_life_capital_snapshots.sql` 縺ｧ蜿肴丐縲・
- 繝ｩ繧､繝戊ｳ・悽繧ｹ繝翫ャ繝励す繝ｧ繝・ヨ Supabase蜷梧悄: 繝ｭ繧ｰ繧､繝ｳ貂医∩繝ｦ繝ｼ繧ｶ繝ｼ縺ｮ繝ｩ繧､繝戊ｳ・悽譌･谺｡繧ｹ繝翫ャ繝励す繝ｧ繝・ヨ繧担upabase縺ｸ蜷梧悄縺励∫ｫｯ譛ｫ蜀・ｱ･豁ｴ縺ｨ繧ｯ繝ｩ繧ｦ繝牙ｱ･豁ｴ繧偵・繝ｼ繧ｸ縲よ悴繝ｭ繧ｰ繧､繝ｳ繝ｻ蜷梧悄螟ｱ謨玲凾縺ｯ遶ｯ譛ｫ蜀・ｱ･豁ｴ縺ｧ邯咏ｶ壹☆繧九Ｎigration `20260422193000_create_life_capital_daily_snapshots.sql` / `20260422194000_wbs_codex_life_capital_cloud_sync.sql` 縺ｧ蜿肴丐縲・
- 繝ｩ繧､繝戊ｳ・悽繧｢繝ｩ繝ｼ繝磯夂衍蟆守ｷ・ 邯咏ｶ壻ｽ惹ｸ九い繝ｩ繝ｼ繝医ｒ譌｢蟄倬夂衍繧ｻ繝ｳ繧ｿ繝ｼ縺ｸ驥崎､・亟豁｢莉倥″縺ｧ騾∽ｿ｡縺励・夂衍縺九ｉ繝帙・繝縺ｮ繝ｩ繧､繝墓ｵｪ雋ｻ繧ｼ繝ｭ蜿ｸ莉､蝪斐∈謌ｻ繧後ｋ繧医≧縺ｫ縺吶ｋ縲Ｎigration `20260422201000_wbs_codex_life_capital_alert_notifications.sql` 縺ｧ蜿肴丐縲・
- 繝ｩ繧､繝戊ｳ・悽鄙呈・蛹悶ご繝ｼ繝・ 邯咏ｶ夂ｳｻ繧ｿ繧ｹ繧ｯ繧貞酔譎ょ､夂匱縺輔○縺壹∵凾髢薙・縺企≡繝ｻ蛛･蠎ｷ繝ｻ菴灘鴨繝ｻ遏･閭ｽ繝ｻ髮・ｸｭ蜉帙・縺・■菴弱ワ繝ｼ繝峨Ν縺ｮ1莉ｶ縺縺代ｒ7譌･邯咏ｶ壹☆繧九∪縺ｧ蝗ｺ螳壹ゆｻ悶・謾ｹ蝟・・隕ｳ蟇溘・縺ｿ縺ｨ縺励・夂衍繧ゅヵ繧ｩ繝ｼ繧ｫ繧ｹ雉・悽繧貞━蜈医☆繧九Ｎigration `20260422202000_wbs_codex_life_capital_habit_gate.sql` 縺ｧ蜿肴丐縲・
- 蜈ｨ讖溯・逕溷多雉・悽KGI/CSF/KPI繝｢繝九ち繝ｼ: HomeToolCatalog 蜈ｨ讖溯・繧呈凾髢薙・縺企≡繝ｻ蛛･蠎ｷ繝ｻ菴灘鴨繝ｻ遏･閭ｽ繝ｻ髮・ｸｭ蜉帙・逕溷多雉・悽縺ｸ蛻・｡槭＠縲∵ｵｪ雋ｻ蜑頑ｸ佞SF/KPI縲∫屮隕夜ｻ蠎ｦ縲、I繝ｬ繝薙Η繝ｼ譁・ц縲∵釜繧翫◆縺溘∩蠑上し繝槭Μ繧定ｿｽ蜉縲Ｎigration `20260422213000_wbs_codex_feature_life_capital_strategy.sql` 縺ｧ蜿肴丐縲・

## Codex 蠑輔″邯吶℃繝｡繝｢ (2026-04-23)

- 莉雁屓螳滄圀縺ｫ逹謇九＠縺溘ち繧ｹ繧ｯ縺ｮ縺ｿ Codex 諡・ｽ薙↓霑ｽ蜉:
  `蜈ｨ讖溯・逕溷多雉・悽繝輔か繝ｼ繧ｫ繧ｹ繧ｲ繝ｼ繝・
- 蜈ｨ讖溯・逕溷多雉・悽繝輔か繝ｼ繧ｫ繧ｹ繧ｲ繝ｼ繝・ 蜈ｨ讖溯・AI謌ｦ逡･繝｢繝九ち繝ｼ縺ｧ縲∵怙繧ょｼｱ縺・函蜻ｽ雉・悽縺九ｉ莉頑律縺ｮ菴弱ワ繝ｼ繝峨Ν1謇九ｒ閾ｪ蜍暮∈螳壹ゆｻ悶・雉・悽繝ｻ讖溯・縺ｯ隕ｳ蟇溘↓蝗槭＠縲∫ｶ咏ｶ夂ｳｻ繧ｿ繧ｹ繧ｯ縺ｮ蜷梧凾螟夂匱繧帝亟縺舌・I繝ｬ繝薙Η繝ｼ縺ｫ繧ゅ％縺ｮ繝輔か繝ｼ繧ｫ繧ｹ諠・ｱ繧呈ｸ｡縺励？ome縺ｫ繝輔か繝ｼ繧ｫ繧ｹ繧ｫ繝ｼ繝峨→縺励※陦ｨ遉ｺ縲Ｎigration `20260423090000_wbs_codex_feature_focus_gate.sql` 縺ｧ蜿肴丐縲・
- 邨ｱ荳蝨ｰ譁ｹ驕ｸ 譛譁ｰ蜿門ｾ励ち繧､繝繧｢繧ｦ繝亥ｾｩ譌ｧ: 譛ｬ逡ｪ縺ｧ `local-election-intelligence` 縺ｮAI隕∫ｴ・≠繧雁叙蠕励′謗･邯壽妙縺ｫ縺ｪ繧狗ｵ瑚ｷｯ繧辰odex縺悟ｼ輔″邯吶℃縲る壼ｸｸ繝繝・す繝･繝懊・繝画峩譁ｰ縺ｯAI隕∫ｴ・↑縺励〒螳滓・繝・・繧ｿ繧貞叙蠕励＠縲：lutter蛛ｴ縺ｮ蠕・ｩ滓凾髢薙ｒ90遘偵∈蟒ｶ髟ｷ縲・dge Function縺ｮOpenAI隕∫ｴ・・6遘偵〒繝輔か繝ｼ繝ｫ繝舌ャ繧ｯ縺吶ｋ縲Ｎigration `20260423170000_wbs_codex_election_latest_fetch_timeout.sql` 縺ｧ蜿肴丐縲・
- 邨ｱ荳蝨ｰ譁ｹ驕ｸ 譛譁ｰ蜿門ｾ佑DP繝吶Φ繝√・繝ｼ繧ｯ莉ｻ諢丞喧: 譛譁ｰ蜿門ｾ励′縺ｪ縺頑凾髢灘・繧後↓縺ｪ繧九◆繧√・壼ｸｸ繝繝・す繝･繝懊・繝画峩譁ｰ縺ｧ縺ｯ遶区・豌台ｸｻ蜈・7逵後・繝ｳ繝√・繝ｼ繧ｯ蜿門ｾ励ｒ蜷梧悄蠢・亥・逅・°繧牙､悶☆縲・DP蛟､縺檎ｩｺ縺ｮ鬮倬溘せ繝翫ャ繝励す繝ｧ繝・ヨ縺ｧ縺ｯ菫晏ｭ俶ｸ医∩KPI繧・荳頑嶌縺阪＠縺ｪ縺・Ｎigration `20260423173000_wbs_codex_election_fast_refresh_benchmarks.sql` 縺ｧ蜿肴丐縲・
- 邨ｱ荳蝨ｰ譁ｹ驕ｸ 蜈ｬ髢九ン繝･繝ｼKPI蜷梧悄菫ｮ豁｣: 譛ｬ逡ｪ縺ｮ鬮倬溘せ繝翫ャ繝励す繝ｧ繝・ヨ縺ｧ縺ｯ莠ｬ驛ｽ蠎・1莠ｺ繧定ｿ斐＠縺ｦ縺・◆荳譁ｹ縲∝・髢九ム繝・す繝･繝懊・繝峨・蜿､縺КPI繝励Λ繝ｳ繧定｡ｨ遉ｺ縺礼ｶ壹￠縺ｦ縺・◆縲ょ・髢九ン繝･繝ｼ縺ｧ繧よ怙譁ｰ繧ｹ繝翫ャ繝励す繝ｧ繝・ヨ蜿嶺ｿ｡譎ゅ↓逵碁｣KPI繝励Λ繝ｳ繧偵Γ繝｢繝ｪ蜷梧悄縺吶ｋ繧医≧菫ｮ豁｣縲Ｎigration `20260423180000_wbs_codex_election_public_view_snapshot_sync.sql` 縺ｧ蜿肴丐縲・
- 雉・肇邂｡逅・驥鷹姦蟆守ｷ夂ｵｱ蜷・ 譌｢縺ｫ Codex 諡・ｽ薙□縺｣縺・`雉・肇邂｡逅・(MoneyForward蟇ｾ謚・ (Codex蠑慕ｶ吶℃)` 繧堤ｶ咏ｶ壼燕騾ｲ縲Ａ謾ｯ蜃ｺ繝医Λ繝・き繝ｼ` 縺ｨ `螳ｶ險医・莠育ｮ励・繝ｩ繝ｳ繝翫・` 縺ｮ螳溷ｰ守ｷ壹ｒ `雉・肇邂｡逅・ 縺ｸ邨ｱ蜷医＠縲∵立繝ｫ繝ｼ繝医・莠呈鋤繝ｩ繝・ヱ繝ｼ縺ｨ縺励※谿九＠縺､縺､縲～MoneyForward騾｣謳ｺ` / `莠育ｮ励・雋｡蜍吶・繝ｩ繝ｳ繝翫・` 縺九ｉ繧りｳ・肇邂｡逅・∈蜊ｳ遘ｻ蜍輔〒縺阪ｋ繧医≧縺ｫ縺励◆縲・I豬ｪ雋ｻ謚大宛繝医Ξ繝ｼ繝九Φ繧ｰ縲゜GI/CSF/KPI縲∝崋螳夊ｲｻ縲∝滄≡繝ｭ繝・け繝繧ｦ繝ｳ繧偵♀驥代・豁｣隕丞ｰ守ｷ壹∈髮・ｴ・Ｎigration `20260423193000_wbs_codex_asset_money_surface_consolidation.sql` 縺ｧ蜿肴丐縲・

- 全機能生命資本別 代表導線ランチャー: `全機能生命資本別 代表導線レーン` を実行導線まで前進。Home の全機能AI戦略モニターから、生命資本ごとの代表機能をその場で直接開けるランチャーと、束ねたサブ導線一覧を追加し、分析結果を即行動へつなげました。時間・お金・健康・体力・知能・集中力の浪費削減を「見るだけ」で終わらせず、正規機能へ最短遷移できるようにしました。migration `20260423200000_wbs_codex_feature_lane_launcher.sql` で反映。

- ノートコメント Notion風再利用Realtime: NotebookLM のコメントUI方針を既存のノート機能へ適用し、`NoteCommentsPanel` / `NoteCommentsSheet` を共通化しました。ノート編集画面と専用コメント画面で同じコメント面を使い、ドラッガブルな底面シート、Realtime での件数追従、投稿者表示、バッジ更新を一箇所で扱えるようにしています。migration `20260423233000_wbs_codex_note_comments_notion_surface.sql` で反映。

## Codex 引き継ぎメモ (2026-04-27)

- 実担当タスク: `全機能AI連携・ライフ浪費ゼロ運用ループ`
- 担当変更: 実際に着手するこの1件のみ `instance='codex' / owner_instance='codex'` としてWBSに追加。
- 対応内容: 既存の `FeatureStrategyMonitor` と `LifeWasteElimination` の抽象を再利用し、重複ダッシュボードを増やさず、ライフ浪費ゼロ司令塔に「今日の運用ループ」を追加。現状、KGI、CSF、数値KPI、毎日モニタリング、改善の1手、拡張しない条件を同じUIで確認できるようにしました。
- WBS DB反映: migration `20260427004000_wbs_codex_life_ai_operating_loop.sql`

## 繝槭う繝ｫ繧ｹ繝医・繝ｳ讎りｦ・(繝ｦ繝ｼ繧ｶ繝ｼ蜿ｯ隕・

| | ﾎｱ迚・| ﾎｲ迚・| 譛邨ら沿 v1.0 |
|---|---|---|---|
| **逶ｮ讓呎律** | 2026-05-31 | 2026-07-31 | 2026-10-31 |
| **谿区律謨ｰ** | 44譌･ | 105譌･ | 197譌･ |
| **繝ｦ繝ｼ繧ｶ繝ｼ逶ｮ讓・* | 50莠ｺ | 500莠ｺ | 5,000莠ｺ |

---

## 繝ｪ繝ｪ繝ｼ繧ｹ繝槭う繝ｫ繧ｹ繝医・繝ｳ

| 繝槭う繝ｫ繧ｹ繝医・繝ｳ | 逶ｮ讓呎律 | 繝ｦ繝ｼ繧ｶ繝ｼ逶ｮ讓・| 讎りｦ・|
|---|---|---|---|
| **ﾎｱ迚・* | 2026-05-31 | 50莠ｺ | 繧ｳ繧｢讖溯・螳牙ｮ壼喧繝ｻCI/CD螳悟・閾ｪ蜍募喧 |
| **ﾎｲ迚・* | 2026-07-31 | 500莠ｺ | 蜈ｨAI邨ｱ蜷医・蜈ｬ髢九・繝ｼ繧ｿ繝ｻ繧ｰ繝ｭ繝ｼ繧ｹ閾ｪ蜍募喧螳梧・ |
| **譛邨ら沿 v1.0** | 2026-10-31 | 5,000莠ｺ | 遶ｶ蜷・1遉ｾ蜈ｨ讖溯・蟇ｾ謚励・蜿守寢蛹夜幕蟋・|

---

## WBS 繧ｿ繧ｹ繧ｯ荳隕ｧ (繧､繝ｳ繧ｹ繧ｿ繝ｳ繧ｹ蛻･諡・ｽ・

### 🚀 カテゴリ1: インフラ・CI/CD - **PowerShell版 / Codex 一時引継ぎ**

| タスク | 担当 | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|---|
| EFハードクォータ16本継続 | PS | 🚀進行中 | 90% | α |
| deploy-prod 成功率100%継続 | PS | 🚀進行中 | 80% | α |
| BYPASS_RULES secret設定 (Codex引継ぎ) | Codex | ✅完了 | 100% | α |
| cs-check最適化完了 | PS | ✅完了 | 100% | α |
| orphan branch 0本継続 | PS | ✅完了 | 100% | α |
| Rule17 WF health weekly実施 | PS | 🚀進行中 | 70% | β |

### 耳 繧ｫ繝・ざ繝ｪ2: 繝・じ繧､繝ｳ繧ｷ繧ｹ繝・Β 窶・**GitHub Co-Pilot / Codex 荳譎ょｼ慕ｶ吶℃**

| 繧ｿ繧ｹ繧ｯ | 迥ｶ諷・| 騾ｲ謐・| ﾎｱ/ﾎｲ/v1 |
|---|---|---|---|
| DESIGN.md蜈ｨ繝壹・繧ｸ貅匁侠 60%驕疲・ (Codex蠑慕ｶ吶℃) | 泯騾ｲ陦御ｸｭ | 73% | ﾎｱ |
| 繝｢繝舌う繝ｫ繝ｬ繧ｹ繝昴Φ繧ｷ繝門ｮ悟・蟇ｾ蠢・(Codex蠑慕ｶ吶℃) | 泯騾ｲ陦御ｸｭ | 78% | ﾎｱ |
| 繧ｿ繧､繝昴げ繝ｩ繝輔ぅ邨ｱ荳 (Codex蠑慕ｶ吶℃) | 泯騾ｲ陦御ｸｭ | 65% | ﾎｲ |
| DESIGN.md蜈ｨ繝壹・繧ｸ貅匁侠 100%驕疲・ | 笞ｪ譛ｪ逹謇・| 0% | v1 |

### 雌 繧ｫ繝・ざ繝ｪ3: AI螟ｧ蟄ｦ 窶・**Windows迚・+ VSCode迚・/ Codex 荳譎ょｼ慕ｶ吶℃**

| 繧ｿ繧ｹ繧ｯ | 諡・ｽ・| 迥ｶ諷・| 騾ｲ謐・| ﾎｱ/ﾎｲ/v1 |
|---|---|---|---|---|
| 78遉ｾ繧ｳ繝ｳ繝・Φ繝・ｮ悟・蛹・| Windows | 泯騾ｲ陦御ｸｭ | 85% | ﾎｱ |
| FSRS蟄ｦ鄙偵す繧ｹ繝・Β螳悟・螳溯｣・(Codex蠑慕ｶ吶℃) | Codex | 泯騾ｲ陦御ｸｭ | 92% | ﾎｱ |
| 繧ｹ繝医Μ繝ｼ繧ｯ繝ｻ繝舌ャ繧ｸ繝ｻ繝ｩ繝ｳ繧ｭ繝ｳ繧ｰ | VSCode | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| AI繝励Ο繝舌う繝繝ｼ荳隕ｧ繝ｻ繝√Ε繝・ヨ讖溯・ | PS | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| AI螟ｧ蟄ｦ 100遉ｾ驕疲・ | Codex | 泯騾ｲ陦御ｸｭ | 12% | ﾎｲ |
| 髻ｳ螢ｰ蟄ｦ鄙呈ｩ溯・蠑ｷ蛹・| VSCode | 泯騾ｲ陦御ｸｭ | 40% | ﾎｲ |

### 直 繧ｫ繝・ざ繝ｪ4: 繧ｳ繧｢SaaS讖溯・ 窶・**VSCode迚・/ Codex 荳譎ょｼ慕ｶ吶℃**

| 繧ｿ繧ｹ繧ｯ | 迥ｶ諷・| 騾ｲ謐・| ﾎｱ/ﾎｲ/v1 |
|---|---|---|---|
| 繝弱・繝医・繝｡繝｢讖溯・ (Notion蟇ｾ謚・ | 泯騾ｲ陦御ｸｭ | 60% | ﾎｲ |
| 繧ｿ繧ｹ繧ｯ邂｡逅・(Asana蟇ｾ謚・ | 泯騾ｲ陦御ｸｭ | 50% | ﾎｲ |
| 雉・肇邂｡逅・(MoneyForward蟇ｾ謚・ (Codex蠑慕ｶ吶℃) | 泯騾ｲ陦御ｸｭ | 64% | ﾎｲ |
| 雉・肇邂｡逅・豬ｪ雋ｻ謚大宛AI繝医Ξ繝ｼ繝九Φ繧ｰ | 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 繝ｩ繧､繝墓ｵｪ雋ｻ繧ｼ繝ｭ蜿ｸ莉､蝪・+ AI謚ｽ雎｡蛹・| 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 繝ｩ繧､繝戊ｳ・悽譌･谺｡繧ｹ繝翫ャ繝励す繝ｧ繝・ヨ + 邯咏ｶ壻ｽ惹ｸ九い繝ｩ繝ｼ繝・| 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 繝ｩ繧､繝戊ｳ・悽繧ｹ繝翫ャ繝励す繝ｧ繝・ヨ Supabase蜷梧悄 | 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 繝ｩ繧､繝戊ｳ・悽繧｢繝ｩ繝ｼ繝磯夂衍蟆守ｷ・| 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 繝ｩ繧､繝戊ｳ・悽鄙呈・蛹悶ご繝ｼ繝・| 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 遶ｶ蜷域ｯ碑ｼ・・繝ｼ繧ｸ譛譁ｰ蛹・(Codex蠑慕ｶ吶℃) | 泯騾ｲ陦御ｸｭ | 85% | ﾎｱ |
| 隱ｲ驥第ｩ溯・螳溯｣・(Stripe) | 笞ｪ譛ｪ逹謇・| 0% | v1 |

### ､・繧ｫ繝・ざ繝ｪ5: AI邨ｱ蜷・窶・**PS迚・+ VSCode迚・/ Codex 荳譎ょｼ慕ｶ吶℃**

| 繧ｿ繧ｹ繧ｯ | 諡・ｽ・| 迥ｶ諷・| 騾ｲ謐・| ﾎｱ/ﾎｲ/v1 |
|---|---|---|---|---|
| ai-hub 502繧ｨ繝ｩ繝ｼ譬ｹ譛ｬ菫ｮ豁｣ | PS | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| ai-hub provider.chat 蜈ｨ蟇ｾ蠢・| PS+Win | 泯騾ｲ陦御ｸｭ | 20% | ﾎｲ | (13/78遉ｾ螳溯｣・窶・Windows#74縺ｧ OpenAI莠呈鋤8+迢ｬ閾ｪ3+迚ｹ谿・ 霑ｽ蜉)
| AI繧｢繧ｷ繧ｹ繧ｿ繝ｳ繝・Opus4.7/Sonnet4.6譖ｴ譁ｰ | VSCode | 泯騾ｲ陦御ｸｭ | 80% | ﾎｱ |
| 逕ｻ蜒冗函謌千ｵｱ蜷・| Codex | 泯騾ｲ陦御ｸｭ | 35% | v1 |
| 繝槭Ν繝√Δ繝ｼ繝繝ｫAI | Codex | 泯騾ｲ陦御ｸｭ | 30% | v1 |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ AI閾ｪ蜍必PI譖ｴ譁ｰ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ AI閾ｪ蜍墓峩譁ｰ蟆ら畑UI | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 繧｢繧ｳ繝ｼ繝・ぅ繧ｪ繝ｳUI謾ｹ蝟・| Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 遶区・豈碑ｼ・UX謾ｹ蝟・| Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 逵碁｣KPI X蜈ｱ譛・| Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 蜈ｬ髢偽RL/荳諡ｬ蜈ｱ譛峨ヮ繝ｼ繝・| Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ KGI/CSF/KPI險ｭ險・| Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 逵碁｣蛻･迴ｾ螳溽岼讓吝・隱ｿ謨ｴ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 謫∫ｫ狗岼讓・蠖馴∈邇⑫PI隱ｿ謨ｴ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 蜈ｨ菴適GI/CSF/KPI陦ｨ遉ｺ蝓ｺ逶､ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 蜈ｨ讖溯・AI謌ｦ逡･繝｢繝九ち繝ｪ繝ｳ繧ｰ蝓ｺ逶､ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 蜈ｨ讖溯・AI謌ｦ逡･繝ｬ繝薙Η繝ｼ螳蘗I騾｣謳ｺ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 蜈ｨ讖溯・逕溷多雉・悽蛻･ 莉｣陦ｨ蟆守ｷ壹Ξ繝ｼ繝ｳ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 蜈ｨ讖溯・逕溷多雉・悽蛻･ 莉｣陦ｨ蟆守ｷ壹Λ繝ｳ繝√Ε繝ｼ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 蜈ｨ讖溯・逕溷多雉・悽蝗槫ｾｩ繝ｭ繝ｼ繝峨・繝・・ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 繧ｵ繧､繝域｡亥・AI繝√Ε繝・ヨ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｲ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 逵碁｣蠖ｹ蜩｡陦ｨ遉ｺ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 蝨ｰ譁ｹ隴ｰ蜩｡髮・ｨ医ヮ繝ｼ繝亥喧蟆守ｷ・| Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 譛譁ｰ蜿門ｾ励ち繧､繝繧｢繧ｦ繝亥ｾｩ譌ｧ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 譛譁ｰ蜿門ｾ佑DP繝吶Φ繝√・繝ｼ繧ｯ莉ｻ諢丞喧 | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |
| 邨ｱ荳蝨ｰ譁ｹ驕ｸ 蜈ｬ髢九ン繝･繝ｼKPI蜷梧悄菫ｮ豁｣ | Codex | 笨・ｮ御ｺ・| 100% | ﾎｱ |

### 嶋 繧ｫ繝・ざ繝ｪ6: 繧ｰ繝ｭ繝ｼ繧ｹ閾ｪ蜍募喧 窶・**PS迚・+ Codex 諡・ｽ・*

| 繧ｿ繧ｹ繧ｯ | 迥ｶ諷・| 騾ｲ謐・| ﾎｱ/ﾎｲ/v1 |
|---|---|---|---|
| 繝悶Ο繧ｰ閾ｪ蜍墓兜遞ｿ螳牙ｮ壼喧 (Qiita/dev.to) | 泯騾ｲ陦御ｸｭ | 75% | ﾎｱ |
| X閾ｪ蜍墓兜遞ｿ daily-report騾｣謳ｺ | 泯騾ｲ陦御ｸｭ | 60% | ﾎｱ |
| YouTube遶ｶ蜷亥・譫占・蜍募喧 | 泯騾ｲ陦御ｸｭ | 70% | ﾎｲ |
| 遶ｶ蜷・1遉ｾ繝｢繝九ち繝ｪ繝ｳ繧ｰ閾ｪ蜍募喧 | 泯騾ｲ陦御ｸｭ | 50% | ﾎｲ |
| NotebookLM Master Brain螳悟・豢ｻ逕ｨ | 泯騾ｲ陦御ｸｭ | 70% | ﾎｲ |

### 則 繧ｫ繝・ざ繝ｪ7: 繝ｦ繝ｼ繧ｶ繝ｼ迯ｲ蠕・窶・**蜈ｨ繧､繝ｳ繧ｹ繧ｿ繝ｳ繧ｹ / Codex 荳譎ょｼ慕ｶ吶℃**

| 繧ｿ繧ｹ繧ｯ | 迥ｶ諷・| 騾ｲ謐・| ﾎｱ/ﾎｲ/v1 |
|---|---|---|---|
| LP譛驕ｩ蛹・(120縺ｮ縺薙→螳悟・謗ｲ霈・ | 泯騾ｲ陦御ｸｭ | 70% | ﾎｱ |
| SEO謾ｹ蝟・(sitemap繝ｻmeta tags) (Codex蠑慕ｶ吶℃) | 泯騾ｲ陦御ｸｭ | 85% | ﾎｱ |
| 繧ｪ繝ｳ繝懊・繝・ぅ繝ｳ繧ｰ譛驕ｩ蛹・(Codex蠑慕ｶ吶℃) | 泯騾ｲ陦御ｸｭ | 35% | ﾎｲ |
| 邏ｹ莉九・繝ｭ繧ｰ繝ｩ繝螳溯｣・(Codex蠑慕ｶ吶℃) | 泯騾ｲ陦御ｸｭ | 25% | ﾎｲ |
| **繝ｦ繝ｼ繧ｶ繝ｼ謨ｰ50莠ｺ驕疲・ (ﾎｱ迚育岼讓・** | 泯騾ｲ陦御ｸｭ | 8% | ﾎｱ |
| **繝ｦ繝ｼ繧ｶ繝ｼ謨ｰ500莠ｺ驕疲・ (ﾎｲ迚育岼讓・** | 笞ｪ譛ｪ逹謇・| 0% | ﾎｲ |
| **繝ｦ繝ｼ繧ｶ繝ｼ謨ｰ5000莠ｺ驕疲・ (v1逶ｮ讓・** | 笞ｪ譛ｪ逹謇・| 0% | v1 |

### 孱・・繧ｫ繝・ざ繝ｪ8: 蜩∬ｳｪ繝ｻ螳牙ｮ壽ｧ 窶・**蜈ｨ繧､繝ｳ繧ｹ繧ｿ繝ｳ繧ｹ / Codex 荳譎ょｼ慕ｶ吶℃**

| 繧ｿ繧ｹ繧ｯ | 諡・ｽ・| 迥ｶ諷・| 騾ｲ謐・| ﾎｱ/ﾎｲ/v1 |
|---|---|---|---|---|
| flutter analyze 0繧ｨ繝ｩ繝ｼ蟶ｸ譎らｶｭ謖・| VSCode | 泯騾ｲ陦御ｸｭ | 85% | ﾎｱ |
| deno lint 0繧ｨ繝ｩ繝ｼ邯ｭ謖・| PS | 泯騾ｲ陦御ｸｭ | 85% | ﾎｱ |
| Web繝代ヵ繧ｩ繝ｼ繝槭Φ繧ｹ譛驕ｩ蛹・| Codex | 泯騾ｲ陦御ｸｭ | 40% | ﾎｲ |
| E2E繝・せ繝域紛蛯・(Playwright) | Codex | 泯騾ｲ陦御ｸｭ | 20% | v1 |
| 繧ｨ繝ｩ繝ｼ逶｣隕門ｼｷ蛹・(Sentry騾｣謳ｺ) | Codex | 泯騾ｲ陦御ｸｭ | 25% | v1 |

### 🛠️ カテゴリ9: 製品ライフサイクル管理 (企画・設計・テスト・リリース・運用・保守)

| タスク | 担当 | 状態 | 進捗 | α/β/v1 |
|---|---|---|---|---|
| [企画] ユーザー要望・新規企画の自動収集とバックログ優先度評価AI連携 | Codex | 🚀進行中 | 20% | β |
| [設計] 全機能詳細設計仕様書 (DESIGN_SPEC) のAI半自動レビューと更新 | Codex | 🚀進行中 | 10% | β |
| [テスト] インテグレーション・回帰自動テストカバレッジの継続監視とレポート | PS | 🚀進行中 | 30% | β |
| [リリース] マルチプラットフォーム (Web, Android, iOS) リリースチェックリスト自動監査 | PS | 🚀進行中 | 40% | β |
| [保守・実運用] 本番インフラヘルス監視と自動ロールバック・保守体制 | PS | 🚀進行中 | 50% | β |

---

## 繧､繝ｳ繧ｹ繧ｿ繝ｳ繧ｹ蛻･ 蜆ｪ蜈医ち繧ｹ繧ｯ

### VSCode迚・窶・谺｡蝗槭そ繝・す繝ｧ繝ｳ蜆ｪ蜈医ち繧ｹ繧ｯ
1. DESIGN.md貅匁侠 竊・60%蛻ｰ驕斐°繧画ｮ九ｊ荳ｻ隕√・繝ｼ繧ｸ縺ｸ螻暮幕
2. FSRS蟄ｦ鄙偵す繧ｹ繝・Β 谿九ｊ8% (Codex蠑慕ｶ吶℃: 隧穂ｾ｡/谺｡蝗槫ｾｩ鄙偵Λ繝吶Ν菫ｮ豁｣繝ｻ蝗槫ｸｰ繝・せ繝郁ｿｽ蜉)
3. 繝弱・繝域ｩ溯・蠑ｷ蛹・(Notion蟇ｾ謚・
4. 繝｢繝舌う繝ｫ繝ｬ繧ｹ繝昴Φ繧ｷ繝也｢ｺ隱・

### Windows迚・窶・谺｡蝗槭そ繝・す繝ｧ繝ｳ蜆ｪ蜈医ち繧ｹ繧ｯ
1. AI螟ｧ蟄ｦ 78竊・5遉ｾ繧ｳ繝ｳ繝・Φ繝・ｿｽ蜉
2. 豈弱そ繝・す繝ｧ繝ｳ2遉ｾ繝舌ャ繝∬ｿｽ蜉邯咏ｶ・
3. docs Rule10蜈ｨ莉ｶ繝√ぉ繝・け

### PowerShell迚・窶・谺｡蝗槭そ繝・す繝ｧ繝ｳ蜆ｪ蜈医ち繧ｹ繧ｯ
1. BYPASS_RULES secret設定 (Codex引継ぎ) ── ✅完了 (検証およびsmoke test成功、ローテーション手順整備完了)
2. ai-hub provider.chat 谿九ｊ60繝励Ο繝舌う繝繝ｼ蟇ｾ蠢・
3. Rule17 WF health check
4. T-1繝悶Ο繧ｰ谺｡蠑ｾ dispatch

---

## 騾ｲ謐玲峩譁ｰ繝ｫ繝ｼ繝ｫ

## Codex 引き継ぎメモ (2026-04-24)

- Harvey 法務レビュー基盤: `[追加要望] legal-assistant EF: Harvey APIをtools-hub の新actionとして追加可能` と `[追加要望] LP掲載: 「法務管理」コア機能のバックエンドとしてHarveyをアピール材料に` を Codex で着手・完了。`tools-hub` に `legal.harvey.complete` を追加し、Harvey Completion API を `HARVEY_API_KEY` 経由で呼べるようにしました。法務管理ページには Harvey 実行タブを追加し、契約レビューや法務メモの草案をその場で試せるようにしています。LP の法務管理カードも Harvey 連携を含む説明へ更新しました。

蜷・そ繝・す繝ｧ繝ｳ邨ゆｺ・凾縺ｫ `wbs_tasks` 繝・・繝悶Ν縺ｮ progress 縺ｨ status 繧呈峩譁ｰ縺吶ｋ縺薙→:

```sql
-- 萓・ ai-hub provider.chat 騾ｲ謐玲峩譁ｰ
UPDATE wbs_tasks SET progress = 30, status = 'in_progress'
WHERE title = 'ai-hub provider.chat 蜈ｨ蟇ｾ蠢・;
```

縺ｾ縺溘・ `/project-gantt` 繝壹・繧ｸ縺九ｉUI譖ｴ譁ｰ (邂｡逅・・・縺ｿ)縲・

---

## 蜿ら・繝ｪ繝ｳ繧ｯ

- **譛ｬ逡ｪ繧ｵ繧､繝・*: https://my-web-app-b67f4.web.app/project-gantt
- **ROADMAP**: `docs/GROWTH_STRATEGY_ROADMAP.md`
- **DESIGN.md**: `docs/DESIGN.md`
- **COMPRESSED_PROMPT**: `.github/COMPRESSED_PROMPT_V3.md`

---

## 逶ｴ霑大ｮ御ｺ・・岼 (2026-04-22 Codex)

- 笨・邨ｱ荳蝨ｰ譁ｹ驕ｸ700蠢・＃邂｡逅・ｮ､縺ｫ蜈ｨ蝗ｽKPI繝槭ャ繝励ｒ霑ｽ蜉
- 笨・蝨ｰ蝗ｳ繧ｿ繧､繝ｫ繝ｻ隧ｳ邏ｰ繝代ロ繝ｫ繝ｻ蜃｡萓九ｒ繝｢繝舌う繝ｫ/繝・せ繧ｯ繝医ャ繝嶺ｸ｡蟇ｾ蠢懊〒螳溯｣・
- 笨・驕ｸ謖吶メ繝｣繝ｼ繝・idget繝・せ繝医・譁・ｭ怜喧縺第悄蠕・､繧剃ｿｮ豁｣縺励゜PI繝槭ャ繝怜屓蟶ｰ繝・せ繝医ｒ霑ｽ蜉
- 笨・譌･譛ｬ蝨ｰ蝗ｳUI縺ｫ豬ｷ髱｢閭梧勹繝ｻ蝨ｰ蝓溘Λ繝吶Ν繝ｻ驕ｸ謚樔ｸｭ逵碁｣繝舌ャ繧ｸ繝ｻ驥咲せ蠎ｦ繝舌・繧定ｿｽ蜉
- 笨・邨ｱ荳蝨ｰ譁ｹ驕ｸAI騾｣謳ｺ繧貞ｼｷ蛹悶＠縲∝推逵碁｣縺ｮ迴ｾ閨ｷ莠ｺ謨ｰ繝ｻ逶ｮ讓呎刀遶区焚繝ｻ莠亥ｮ夐∈謖呎焚繝ｻ蜈ｬ隱肴悄髯舌ｒ閾ｪ蜍墓峩譁ｰ
- 笨・謇句・蜉帙〒KPI繧貞､画峩縺ｧ縺阪ｋUI繧呈彫蜴ｻ縺励√く繝｣繝・す繝･貂医∩AI繝・・繧ｿ繧ょ・譛溯｡ｨ遉ｺ譎ゅ↓閾ｪ蜍募酔譛・
- 笨・逵碁｣荳隕ｧ繝ｻ隴ｰ蜩｡蜷咲ｰｿ繝ｻ蜈ｬ蠑上た繝ｼ繧ｹ繧偵い繧ｳ繝ｼ繝・ぅ繧ｪ繝ｳ蛹悶＠縲・聞縺・Μ繧ｹ繝医ｒ逡ｳ繧√ｋUI縺ｸ謾ｹ蝟・
- 笨・遶区・豌台ｸｻ蜈壼・蠑上瑚・豐ｻ菴楢ｭｰ蜩｡縲肴ュ蝣ｱ縺ｮ逵悟挨閾ｪ蜍暮寔險医ｒ霑ｽ蜉縺励√・繝ｳ繝√・繝ｼ繧ｯ/逵悟挨繧ｫ繝ｼ繝・蝨ｰ蝗ｳ隧ｳ邏ｰ縺ｸ蜿肴丐
- 笨・逵碁｣KPI縺ｮ蜈ｱ譛画枚逕滓・縺ｨ蜈ｬ髢偽RL蟆守ｷ壹ｒ霑ｽ蜉縺励∵怙邨６I縺ｯ荳諡ｬ蜈ｱ譛峨ヮ繝ｼ繝域婿蠑上∈邨ｱ蜷・
- 笨・譛ｪ繝ｭ繧ｰ繧､繝ｳ縺ｧ繧ら峩謗･URL縺ｧ蜿ら・縺ｧ縺阪ｋ蜈ｬ髢九ン繝･繝ｼ縺ｨ縲∝・逵碁｣KPI繧・縺､縺ｮ蜈ｱ譛峨ヮ繝ｼ繝医↓縺ｾ縺ｨ繧√※X蜈ｱ譛峨☆繧句ｰ守ｷ壹ｒ霑ｽ蜉

## 逶ｴ霑大ｮ御ｺ・・岼 (2026-04-17 Windows迚・74)

- 笨・AI螟ｧ蟄ｦ 77竊・8遉ｾ (SambaNova SN50 RDU 霑ｽ蜉) 窶・ﾎｱ驕疲・蠎ｦ+1.3%
- 笨・AI繝励Ο繝舌う繝繝ｼ螳溯｣・せ繝・・繧ｿ繧ｹ荳隕ｧ繝壹・繧ｸ (Phase 1)
- 笨・provider.chat 13遉ｾ蟇ｾ蠢・(OpenAI莠呈鋤8 + Mistral/Perplexity/Cohere + Anthropic/Gemini 迚ｹ谿願ｪ崎ｨｼ)
- 笨・ElevenLabs 隱ｲ驥大宛髯・竊・Web Speech API 閾ｪ蜍輔ヵ繧ｩ繝ｼ繝ｫ繝舌ャ繧ｯ
- 笨・繝ｫ繝ｼ繝√Φ2繧ｹ繧ｭ繝ｫ霑ｽ蜉: `cross-instance-pr` / `session-start-check`
- 笨・ai-hub 502 transient incident report
- 笨・Rule 10 docs stale 謨ｰ蛟､菫ｮ豁｣ (56遉ｾ逶ｮ竊・9遉ｾ逶ｮ莉･髯・
- 笨・Rule 11 繝｢繝・Ν landscape 隱ｿ譟ｻ (GPT-5.4/Gemini 3.1/Opus 4.7)
- 笨・Rule 14 繝・・繝ｫ繝舌・繧ｸ繝ｧ繝ｳ蜈ｨ譛譁ｰ遒ｺ隱・

## 谺｡繧ｻ繝・す繝ｧ繝ｳ逹謇区耳螂ｨ (ﾎｱ迚・44譌･蜑・

**譛蜆ｪ蜈・(ﾎｱ髦ｻ螳ｳ)**:
1. PS迚・ BYPASS_RULES secret 險ｭ螳・smoke test (Codex縺ｧ蟄伜惠遒ｺ隱阪・謇矩・紛蛯呎ｸ医∩)
2. VSCode迚・Codex: DESIGN.md貅匁侠 68%竊剃ｸｻ隕√・繝ｼ繧ｸ讓ｪ螻暮幕 (ﾎｱ逶ｮ讓・
3. Windows迚・ AI螟ｧ蟄ｦ 78遉ｾ 竊・quiz/fallback 蜈・ｮ溷喧
4. 蜈ｨ繧､繝ｳ繧ｹ繧ｿ繝ｳ繧ｹ: 繝ｦ繝ｼ繧ｶ繝ｼ謨ｰ 50莠ｺ驕疲・繝峨Λ繧､繝・(迴ｾ蝨ｨ 8% = 4莠ｺ)

**ﾎｱ迚育｢ｺ螳溷喧繧ｿ繧ｹ繧ｯ**:
- flutter analyze 0繧ｨ繝ｩ繝ｼ蟶ｸ譎らｶｭ謖・(迴ｾ 85%)
- deploy-prod 謌仙粥邇・100%邯ｭ謖・
- 繧ｪ繝ｳ繝懊・繝・ぅ繝ｳ繧ｰ譛驕ｩ蛹・(Codex蠑慕ｶ吶℃繝ｻ迴ｾ 35%)
- 邏ｹ莉九・繝ｭ繧ｰ繝ｩ繝螳溯｣・(Codex蠑慕ｶ吶℃繝ｻ迴ｾ 25%)
- E2E繝・せ繝域紛蛯・(Playwright) (Codex蠑慕ｶ吶℃繝ｻ迴ｾ 20%)
- 繧ｨ繝ｩ繝ｼ逶｣隕門ｼｷ蛹・(Sentry騾｣謳ｺ) (Codex蠑慕ｶ吶℃繝ｻ迴ｾ 25%)
- 逕ｻ蜒冗函謌千ｵｱ蜷・(Codex蠑慕ｶ吶℃繝ｻ迴ｾ 35%)
- 繝槭Ν繝√Δ繝ｼ繝繝ｫAI (Codex蠑慕ｶ吶℃繝ｻ迴ｾ 30%)
# Codex霑ｽ險・2026-04-22

- 螳溽捩謇九ち繧ｹ繧ｯ縺ｮ縺ｿCodex諡・ｽ薙∈螟画峩: 縲悟・讖溯・AI謌ｦ逡･繝｢繝九ち繝ｪ繝ｳ繧ｰ 鬘樔ｼｼ讖溯・謚ｽ雎｡蛹悶阪ｒCodex諡・ｽ薙→縺励※螳御ｺ・・
- 蟇ｾ蠢懷・螳ｹ: 蜈ｨ讖溯・縺ｮAI蛻・梵/KGI/CSF/KPI/螳壽悄繝｢繝九ち繝ｪ繝ｳ繧ｰ縺ｫ縲・｡樔ｼｼ讖溯・縺ｮ邨ｱ蜷亥呵｣懊ｒ閾ｪ蜍墓歓蜃ｺ縺吶ｋ繝｢繝・Ν繧定ｿｽ蜉縲ゅΛ繧､繝墓ｵｪ雋ｻ繧ｼ繝ｭ蜿ｸ莉､蝪斐∬ｳ・肇豬ｪ雋ｻ繝医Ξ繝ｼ繝九Φ繧ｰ縲∝・讖溯・謌ｦ逡･繝｢繝九ち繝ｪ繝ｳ繧ｰ縺ｮ譁・ｭ怜喧縺第枚險繧ゆｿｮ豁｣縲・
- WBS DB蜿肴丐: migration `20260422183000_wbs_codex_feature_consolidation_monitor.sql`縲・

# Codex霑ｽ險・2026-04-23

- 螳溽捩謇九ち繧ｹ繧ｯ縺ｮ縺ｿCodex諡・ｽ薙∈螟画峩: 縲悟・讖溯・逕溷多雉・悽繝輔か繝ｼ繧ｫ繧ｹ螳御ｺ・Ν繝ｼ繝励阪ｒCodex諡・ｽ薙→縺励※螳御ｺ・・
- 蟇ｾ蠢懷・螳ｹ: 蜈ｨ讖溯・AI謌ｦ逡･繝｢繝九ち繝ｼ縺ｮ縲御ｻ頑律縺ｮ菴弱ワ繝ｼ繝峨Ν1謇九阪ｒ縲∝ｮ御ｺ・∪縺溘・莉頑律縺ｯ隕ｳ蟇溘→縺励※險倬鹸縺ｧ縺阪ｋ繧医≧縺ｫ縺励∫ｶ咏ｶ壽律謨ｰ繧定｡ｨ遉ｺ縲らｶ咏ｶ夂ｳｻ繧ｿ繧ｹ繧ｯ繧貞ｺ・￡縺吶℃縺壹∫ｿ呈・蛹悶☆繧九∪縺ｧ1謇九↓邨槭ｋ謾ｹ蝟・Ν繝ｼ繝励∈譖ｴ譁ｰ縲・
- WBS DB蜿肴丐: migration `20260423093000_wbs_codex_feature_focus_completion.sql`縲・
- 螳溽捩謇九ち繧ｹ繧ｯ縺ｮ縺ｿCodex諡・ｽ薙∈螟画峩: 縲悟・讖溯・逕溷多雉・悽繝輔ぅ繝ｼ繝峨ヰ繝・けKPI縲阪ｒCodex諡・ｽ薙→縺励※螳御ｺ・・
- 蟇ｾ蠢懷・螳ｹ: 菴弱ワ繝ｼ繝峨Ν1謇九・螳御ｺ・・隕ｳ蟇溷ｱ･豁ｴ繧・譌･髢適PI縺ｨ縺励※髮・ｨ医＠縲∝・讖溯・AI謌ｦ逡･繝｢繝九ち繝ｼ縲√・繝ｼ繝医ヵ繧ｩ繝ｪ繧ｪKGI/CSF/KPI縲、I繝ｬ繝薙Η繝ｼ縺ｮ譁・ц縺ｸ蜿肴丐縲らｿ呈・蛹悶☆繧九∪縺ｧ谺｡縺ｸ蠎・￡縺ｪ縺・愛譁ｭ繧呈焚蛟､蛹悶・
- WBS DB蜿肴丐: migration `20260423103000_wbs_codex_feature_focus_feedback.sql`縲・
- 螳溽捩謇九ち繧ｹ繧ｯ縺ｮ縺ｿCodex諡・ｽ薙∈螟画峩: 縲悟・讖溯・逕溷多雉・悽鄙呈・蛹冶ｧ｣謾ｾ繧ｲ繝ｼ繝医阪ｒCodex諡・ｽ薙→縺励※螳御ｺ・・
- 蟇ｾ蠢懷・螳ｹ: 菴弱ワ繝ｼ繝峨Ν1謇九ｒ螳御ｺ・譌･蛻・∪縺溘・3譌･邯咏ｶ壹∪縺ｧ蝗ｺ螳壹＠縲∬ｧ｣謾ｾ譚｡莉ｶ繧呈ｺ縺溘☆縺ｾ縺ｧ譁ｰ縺励＞邯咏ｶ壹ち繧ｹ繧ｯ繧貞｢励ｄ縺輔↑縺・愛螳壹ｒ霑ｽ蜉縲６I縲゜GI/CSF/KPI縲、I繝ｬ繝薙Η繝ｼ縺ｫ隗｣謾ｾ迥ｶ諷九ｒ陦ｨ遉ｺ縲・
- WBS DB蜿肴丐: migration `20260423113000_wbs_codex_feature_habit_unlock.sql`縲・
- 螳溽捩謇九ち繧ｹ繧ｯ縺ｮ縺ｿCodex諡・ｽ薙∈螟画峩: 縲悟・讖溯・逕溷多雉・悽谺｡蛟呵｣懊く繝･繝ｼ縲阪ｒCodex諡・ｽ薙→縺励※螳御ｺ・・
- 蟇ｾ蠢懷・螳ｹ: 迴ｾ蝨ｨ縺ｮ菴弱ワ繝ｼ繝峨Ν1謇九′隗｣謾ｾ縺輔ｌ縺溷ｾ後↓騾ｲ繧谺｡縺ｮ逕溷多雉・悽繝ｻ莉｣陦ｨ讖溯・繧偵く繝･繝ｼ陦ｨ遉ｺ縺励、I繝ｬ繝薙Η繝ｼ縺ｨKGI/CSF/KPI縺ｧ遘ｻ陦碁・ｒ譯亥・縲・
- WBS DB蜿肴丐: migration `20260423201000_wbs_codex_feature_next_focus_queue.sql`縲・
- 螳溽捩謇九ち繧ｹ繧ｯ縺ｮ縺ｿCodex諡・ｽ薙∈螟画峩: 縲悟・讖溯・逕溷多雉・悽蛻･ 莉｣陦ｨ蟆守ｷ壹Ξ繝ｼ繝ｳ縲阪ｒCodex諡・ｽ薙→縺励※螳御ｺ・・
- 蟇ｾ蠢懷・螳ｹ: 譎る俣繝ｻ縺企≡繝ｻ蛛･蠎ｷ繝ｻ菴灘鴨繝ｻ遏･閭ｽ繝ｻ髮・ｸｭ蜉帙＃縺ｨ縺ｫ莉｣陦ｨ讖溯・繧・縺､蝗ｺ螳壹＠縲・｡樔ｼｼ讖溯・繧偵し繝門ｰ守ｷ壹→縺励※譚溘・繧九Ξ繝ｼ繝ｳ繧定ｿｽ蜉縲ゆｻ｣陦ｨ繝ｬ繝ｼ繝ｳ謨ｰ縲∝ｰ守ｷ夊ｿｷ縺・炎貂幄ｦ玖ｾｼ縺ｿ縲゜GI/CSF/KPI縲、I繝ｬ繝薙Η繝ｼ縲∵律谺｡繧ｹ繝翫ャ繝励す繝ｧ繝・ヨ縺ｸ蜿肴丐縲・
- WBS DB蜿肴丐: migration `20260423163000_wbs_codex_life_capital_lane_abstraction.sql`縲・
- 螳溽捩謇九ち繧ｹ繧ｯ縺ｮ縺ｿCodex諡・ｽ薙∈螟画峩: 縲悟・讖溯・逕溷多雉・悽蝗槫ｾｩ繝ｭ繝ｼ繝峨・繝・・縲阪ｒCodex諡・ｽ薙→縺励※螳御ｺ・・
- 蟇ｾ蠢懷・螳ｹ: 逕溷多雉・悽縺斐→縺ｮ莉｣陦ｨ蟆守ｷ壹ｒ蠑ｱ縺・・↓荳ｦ縺ｹ縲√＞縺ｾ逹謇倶ｸｭ繝ｻ谺｡縺ｫ騾ｲ繧蛟呵｣懊・縺昴・蠕後↓謗ｧ縺医ｋ謾ｹ蝟・ｒ荳縺､縺ｮ蝗槫ｾｩ繝ｭ繝ｼ繝峨・繝・・縺ｨ縺励※蜿ｯ隕門喧縲ょ・讖溯・AI謌ｦ逡･繝｢繝九ち繝ｼ縲゜GI/CSF/KPI縲、I繝ｬ繝薙Η繝ｼ縲√せ繝翫ャ繝励す繝ｧ繝・ヨ縺ｮ谺｡繧｢繧ｯ繧ｷ繝ｧ繝ｳ縺ｸ謗･邯壹・
- WBS DB蜿肴丐: migration `20260423213000_wbs_codex_feature_recovery_roadmap.sql`縲・
- 螳溽捩謇九ち繧ｹ繧ｯ縺ｮ縺ｿCodex諡・ｽ薙∈螟画峩: 縲後し繧､繝域｡亥・AI繝√Ε繝・ヨ縲阪ｒCodex諡・ｽ薙→縺励※螳御ｺ・・- 蟇ｾ蠢懷・螳ｹ: Home 縺ｫ縲郡ITE GUIDE AI縲阪そ繧ｯ繧ｷ繝ｧ繝ｳ縺ｨ蝗ｺ螳壼ｰ守ｷ壹ｒ霑ｽ蜉縺励√し繧､繝亥・讖溯・縺ｮ菴ｿ縺・婿繝ｻ蜈･蜿｣繝ｻ縺翫☆縺吶ａ蟆守ｷ壹ｒ雉ｪ蝠上〒縺阪ｋ繝√Ε繝・ヨ繝壹・繧ｸ繧・ai-hub provider.chat 繝吶・繧ｹ縺ｧ螳溯｣・・I螟ｱ謨玲凾繧ゅΟ繝ｼ繧ｫ繝ｫ蛟呵｣懊°繧画｡亥・縺励・未騾｣讖溯・繧偵◎縺ｮ縺ｾ縺ｾ髢九￠繧九・- WBS DB蜿肴丐: migration `20260423223000_wbs_codex_site_guide_chatbot.sql`縲・

# Codex更新 2026-04-24

- 実担当タスク: `[追加要望] AIアシスタント動画`
- 対応内容: `ai-assistant` Edge Function に Hedra 動画回答アクションを接続し、`/ai-assistant` チャットから `テキスト回答 / 動画回答` を切り替えて返答動画 URL と状態を受け取れるようにした。
- 実装補足: `ai-hub my_agent.chat(video)` から `ai-assistant assistant_video_reply` を呼び、`HEDRA_API_KEY` 未設定時や失敗時はテキスト回答へフォールバックする。
- WBS DB反映: migration `20260424113000_wbs_codex_ai_assistant_video.sql`
- 実担当タスク: `[追加要望] バイラル動画パイプライン強化`
- 対応内容: `viral-video-ad-generator` に Hedra プレゼンター動画生成を追加し、バイラル広告ジェネレーター画面から `画像広告 / プレゼンター動画` を切り替えて生成・プレビュー・X 投稿できるようにした。
- 実装補足: `viral_ad_generations` に動画URL系カラムを追加し、Hedra 失敗時は理由を表示してテキスト投稿へフォールバックする。履歴でも動画広告を開けるようにした。
- WBS DB反映: migration `20260425001000_wbs_codex_viral_video_presenter.sql`
- 実担当タスク: `[追加要望] ギター評価の進化` / `[追加要望] ギター評価フィードバック`
- 対応内容: ギターレコーディングスタジオの `AIギターコーチ` タブにアバター解説生成を追加し、最新の演奏評価結果と練習分析をもとに Hedra 動画で口頭フィードバックを返せるようにした。
- 実装補足: `ai-hub my_agent.chat(video)` を使って動画化し、動画URLが返らないときもスクリプトと理由を残して改善ポイントを確認できるようにした。
- WBS DB反映: migration `20260425003000_wbs_codex_guitar_avatar_feedback.sql`
- 実担当タスク: `[追加要望] AI大学のコンテンツ形式革新`
- 対応内容: AI大学に `/ai-university-video` を追加し、教材テキストをもとに Hedra 動画レッスンを生成できるようにした。HomeカードとAI大学本体から遷移可能。
- 実装補足: `ai-hub my_agent.chat(video)` に `title / voice / conversation_context` の pass-through を追加。
- WBS DB反映: migration `20260424163000_wbs_codex_ai_university_video_lesson.sql`
- 実担当タスク: `[追加要望] Edge FunctionでのLLM呼び出し`
- 対応内容: `ai-hub` に `edge_llm.invoke` を追加し、system prompt / user prompt / context JSON / text・JSON応答形式をまとめて Edge Function 経由で実行できるようにした。Home から `Edge LLM Playground` を開いて試せる。
- 実装補足: `edge_llm.invoke` は自動 tier ルーティングと observability 返却に対応し、JSON 指定時は `parsed_json` も返す。
- WBS DB反映: migration `20260424174500_wbs_codex_edge_llm_invoke.sql`
- 実担当タスク: `[追加要望] github-issue-fix.yml + ci-auto-fix.yml = Devin的な自立修正パターン`
- 対応内容: `github-issue-fix.yml` を新設し、Open Issue を oldest-first で 1 件選んで修正ブランチ・修正計画・draft PR を自動作成するオーケストレーターを追加した。以後の CI は既存 `ci-auto-fix.yml` と組み合わせて小さな自動修復ループに載せられる。
- 実装補足: `workflow_dispatch` で Issue 番号を直接指定でき、対象がない場合は skip summary のみ返す。作成した plan は `docs/issue-fix-plans/issue-<number>.md` に保存する。
- WBS DB反映: migration `20260424193000_wbs_codex_github_issue_fix_workflow.sql`
- 実担当タスク: `[追加要望] ゴール: Claude Code 4インスタンスを「自社Devin」として機能させる`
- 対応内容: Admin Analytics に `Self Devin control tower` を追加し、VSCode / WEB / Win / PowerShell の 4 レーンごとの進行、追加要望タスク件数、詰まり、平均進捗を一画面で見えるようにした。
- 実装補足: `schedule_task_runs` をもとに `cs-check / github-issue-fix / ci-auto-fix / infra-health-check` の自動化ループ状態を集約し、次に救援すべきレーンを recommendation として表示する。`ScheduleTaskMonitorCard` にも `github-issue-fix` と `ci-auto-fix` を追加した。
- WBS DB反映: migration `20260424213000_wbs_codex_self_devin_control_tower.sql`
- 実担当タスク: `[追加要望] AI大学コンテンツ: 法律AIという新ジャンルを開拓（競合は未対応が多い）`
- 対応内容: AI大学トップとHomeカードに `法律AI` ジャンル導線を追加し、Harvey を代表教材として契約レビュー・リーガルリサーチ・Due Diligence を学べる入口を新設した。
- 実装補足: `ai_university_genre_catalog` を追加して今後の専門ジャンル展開に備えつつ、`/gemini-university` は引数で代表プロバイダーを直接開けるようにした。Harvey の provider status も `HARVEY_API_KEY` 前提の実装済みに更新。
- WBS DB反映: migration `20260425022000_wbs_codex_ai_university_legal_ai_genre.sql`
- 実担当タスク: `[追加要望] 【HeyGen】多言語SNS展開`
- 対応内容: バイラル広告ジェネレーターの生成結果に `HeyGen 多言語SNS展開` を追加し、日本語・英語・韓国語・中国語・スペイン語の短尺動画原稿、HeyGenリップシンク翻訳指示、X投稿文、LinkedIn投稿文を自動展開できるようにした。
- 実装補足: 各言語ごとに投稿キットをコピーでき、X intent で即投稿画面を開ける。全言語の一括コピーにも対応。
- WBS DB反映: migration `20260425033000_wbs_codex_heygen_multilingual_sns.sql`
- 実担当タスク: `[追加要望] 【HeyGen】AI大学 v3`
- 対応内容: AI大学の動画レッスン画面に `HeyGen AI大学 v3 設計` を追加し、選択教材ごとに HeyGen Avatar V 用の制作ブリーフ、5シーン構成、画面テキスト、多言語展開メモを自動生成できるようにした。
- 実装補足: 動画生成プロンプトも HeyGen v3 前提に更新し、短尺・多言語リップシンク翻訳に崩れにくい教材原稿になるようにした。設計全文はコピー可能。
- WBS DB反映: migration `20260425034500_wbs_codex_heygen_ai_university_v3.sql`
- 実担当タスク: `[追加要望] 【HeyGen】ブログコンテンツの動画化`
- 対応内容: テックブログ投稿管理の Schedule 自動生成下書きを展開すると、各ブログ下書きごとに `HeyGenブログ動画化` ブリーフを確認・コピーできるようにした。
- 実装補足: 下書きタイトル、配信先、URL、draft path から HeyGen Avatar V 用の制作ブリーフ、5シーン構成、SNS投稿文、X / YouTube Shorts / LinkedIn 再利用チェックリストを生成する共通サービスを追加。
- WBS DB反映: migration `20260425040000_wbs_codex_heygen_blog_video.sql`
- 実担当タスク: `[追加要望] 【Manus AI】「Manus like」機能の差別化: 自分株式会社内でのマルチステップタスク自動実行機能`
- 対応内容: AI組織OSに `Manus-like マルチステップ自動実行` を追加し、目的を1つ入力すると要件整理、KGI/CSF/KPI設計、主担当案、専門レビュー、CEO確認準備までを部門タスクへ自動展開できるようにした。
- 実装補足: 目的のキーワードから財務/マーケ/営業/法務/健康/プロダクト/技術などの戦略を判定し、既存の有効エージェントへ5ステップの `agent_tasks` と executive board summary を作成する。
- WBS DB反映: migration `20260425043000_wbs_codex_manus_like_multistep.sql`
- 実担当タスク: `[追加要望] 【Manus AI】競合モニタリング高度化: 週次Manus実行でcompetitor-reportsを自動生成`
- 対応内容: 競合機能同期画面に `Manus週次競合レポート` を追加し、最新の `competitor_feature` を集約して `competitor_report` として保存・確認できるようにした。
- 実装補足: Enterprise Hub に `competitor.reports` と `competitor.weekly_manus_report` を追加し、KGI/CSF/KPI、競合別サマリー、次の実行案をMarkdownで生成する。
- WBS DB反映: migration `20260425050000_wbs_codex_manus_competitor_weekly_report.sql`
- 実担当タスク: `[追加要望] 【Manus AI】マイAIエージェント機能強化: my-ai-agent EFにManusのAPIを選択肢として追加`
- 対応内容: AIアシスタントチャットから `Gemini / Manus` を切り替えられるようにし、Manus選択時は `MANUS_API_KEY` で公式 Manus task.create API に非同期タスクを作成するようにした。
- 実装補足: `ai-hub my_agent.chat(provider=manus)` が task id / task url を返し、履歴にも `agent_provider` と Manus task metadata を保存する。Geminiテキスト回答とHedra動画回答は既存どおり残す。
- WBS DB反映: migration `20260425053000_wbs_codex_manus_my_agent_provider.sql`
- 実担当タスク: `[追加要望] Claude Code Schedule + GitHub Actions = 自作Devinパターン`
- 対応内容: `.github/workflows/self-devin-schedule.yml` を追加し、WBSの追加要望をGitHub Issue修復レーンへ自動ルーティングする日次スケジュールを作った。
- 実装補足: pendingの追加要望を選び、Issueが閉じていればWBSを完了、Issueが開いていれば `github-issue-fix.yml` をdispatch、Issue未作成なら作成してからdispatchする。`schedule_task_runs` には `self-devin-schedule` として記録する。
- WBS DB反映: migration `20260425060000_wbs_codex_self_devin_schedule_router.sql`
- 実担当タスク: `[追加要望] 自分株式会社の「AI大学」機能→ユーザーの学習データもScaleのRLHFコンセプトで品質向上`
- 対応内容: AI大学の各プロバイダー画面に `RLHF quality loop` を追加し、ユーザーの `Useful / Needs fix` 反応を preference signal として保存、教材品質スコア・平均評価・ファインチューニング準備状況・次アクションを表示できるようにした。
- 実装補足: `ai-hub` に `university.rlhf_signal` / `university.rlhf_snapshot` を追加し、`hub_data` の `ai_university_rlhf_signal` をScale風の学習データ品質セットとして集計する。閉じ済みIssue #654/#652 もWBSへ完了同期した。
- WBS DB反映: migration `20260425063000_wbs_codex_ai_university_rlhf_feedback.sql`
- 実担当タスク: `[追加要望] daily-judgment EF → Scale Evaluationパターンで回答品質を自動スコアリング可能`
- 対応内容: `ai-hub judgment.get` の生成結果を KGI / CSF / KPI 付きの構造に正規化し、KGI整合・実行可能性・文脈根拠・明瞭性をScale Evaluation風の品質ゲートで自動採点するようにした。
- 実装補足: ログイン済みユーザーは `daily_judgment_quality_evaluation` として品質スナップショットを保存し、Daily Judgment UIでは総合スコア、しきい値、評価軸、改善アクションを確認できる。
- WBS DB反映: migration `20260425100000_wbs_codex_daily_judgment_scale_eval_start.sql`, `20260425101500_wbs_codex_daily_judgment_scale_eval_done.sql`
- 実担当タスク: `[追加要望] 長期：独自ユーザーデータをファインチューニングに活用（Scale EGP的アプローチ）`
- 対応内容: `ai-hub` に `user_data.finetune_readiness` を追加し、AI大学RLHFシグナルとDaily Judgment品質評価を横断集計して、独自データ活用の準備度をKGI/CSF/KPI付きで返すようにした。
- 実装補足: 生データを即ファインチューニングへ流さず、eligible record数、品質スコア、評価バッチ準備、ファインチューニング準備、PIIリスク、匿名化・holdout方針、次アクションをゲート表示する。AI大学の `RLHF quality loop` には `First-party data tuning readiness` パネルを追加した。
- WBS DB反映: migration `20260425103000_wbs_codex_user_data_finetune_egp_start.sql`, `20260425104500_wbs_codex_user_data_finetune_egp_done.sql`

# Codex更新 2026-04-25

- 実担当タスク: `LP FAQ差別化軸7追加 + FeatureStrategyAiReviewService test fix`
- 対応内容: LPのFAQに、AIベンダー分散、生活資本の浪費削減、KGI/CSF/KPI自動化、習慣化ゲート、サイト内チャット、NotebookLM連携などの差別化軸7件を追加した。
- 実装補足: `FeatureStrategyAiReviewService` のテストは、ローカライズ済みプロンプト断片に依存せず、総機能数・状態別件数・レビュー期限・機能名・`action=` など構造化されたプロンプト事実を検証する形に安定化した。
- WBS DB反映: migration `20260425113000_wbs_codex_lp_faq_feature_strategy_start.sql`, `20260425114500_wbs_codex_lp_faq_feature_strategy_done.sql`
- 実担当タスク: `[追加要望] 【Harvey AI】legal-assistant EF` / `[Issue #707] [追加要望] 【Harvey AI】legal-assistant EF`
- 対応内容: `tools-hub` のHarvey API連携に `legal-assistant.harvey.complete` と `legal-assistant.review` の互換actionを追加し、既存の `legal.harvey.complete` と同じ `HARVEY_API_KEY` ベースのCompletion APIへルーティングできるようにした。
- 実装補足: 法務・コンプライアンス画面のHarveyタブは新しい `legal-assistant.harvey.complete` を呼ぶように更新した。既存actionは後方互換として残す。
- WBS DB反映: migration `20260425125000_wbs_codex_harvey_legal_assistant_start.sql`, `20260425130500_wbs_codex_harvey_legal_assistant_done.sql`
- 実担当タスク: `[追加要望] 【Harvey AI】LP掲載：「法務管理」コア機能のバックエンドとしてHarveyをアピール材料に` / `[Issue #708] [追加要望] 【Harvey AI】LP掲載：「法務管理」コア機能のバックエンドとしてHarveyをアピール材料に`
- 対応内容: LPの機能カードを `法務管理 / Harvey AI` に更新し、契約レビュー・論点整理・引用付き確認をHarveyバックエンドで進められることを明示した。
- 実装補足: FAQにも「法務管理ではHarvey AIをどこに使っているか」を追加し、法務・コンプライアンス画面のHarveyタブとLPの訴求を接続した。
- WBS DB反映: migration `20260425141500_wbs_codex_harvey_lp_start.sql`, `20260425143000_wbs_codex_harvey_lp_done.sql`
- 実担当タスク: `[追加要望] 【Harvey AI】AI大学コンテンツ：法律AIという新ジャンルを開拓（競合は未対応が多い）` / `[Issue #709] [追加要望] 【Harvey AI】AI大学コンテンツ：法律AIという新ジャンルを開拓（競合は未対応が多い）`
- 対応内容: AI大学の `法律AI` ジャンルを、競合がまだ薄いホワイトスペース領域として明示し、Harveyを代表プロバイダーにした新ジャンル訴求へ強化した。
- 実装補足: フォーカス領域に `コンプライアンス` を追加し、契約レビュー・リーガルリサーチ・Due Diligence・コンプライアンスの4軸で学べることをテストでも保証した。
- WBS DB反映: migration `20260425144500_wbs_codex_harvey_legal_ai_genre_start.sql`, `20260425150000_wbs_codex_harvey_legal_ai_genre_done.sql`
