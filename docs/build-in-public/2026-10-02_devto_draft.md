---
title: Building 自分株式会社 — Last 7 Days of AI Fleet Development
published: false
tags: ai, indiedev, buildinpublic, claude
date: 2026-10-02
---

## TL;DR

Last 7 days of building **自分株式会社** (= Jibun Inc. / a personal life-management AI app) with a **12-instance AI fleet** (10 Claude Code + 2 Codex CLI). This post extracts the recent ROADMAP-LOG entries as a build-in-public update.

## Recent activity (auto-extracted)

## 2026-09-27: Inbox draft protection and adaptive confirmation (PR #5544)
- Preserve draft text when back, Escape, or the barrier dismisses Inbox; require explicit discard.

- Keep pending saves open, preserve failed input, and allow retry. Use platform-adaptive discard actions without upgrading Flutter or claiming native Liquid Glass support.

- Verify Android/iOS/Windows widget behavior and desktop/mobile Chromium flows through the existing cloud CI and visual-regression workflow. Production release remains subject to successful checks.

---

## 2026-09-27 Jev Mario World 5 / audio / shared ranking (Issue #5557)
Add independently arranged 5-1..5-4, three-voice original chiptune arrangements with percussion, bounded local attempt history and authenticated opt-in shared self-reported ranking. Rank within course/controller/starting-power/revision; do not claim verified competitive scores, original ROM parity or new-course natural AI clear. Private-schema table, explicit authenticated RPC, ownership-only history, no public auth IDs, bounded retention and serialized submission limits. Cloud CI and final security/release review pending. Local resources CLOUD_REQUIRED; lead gpt-6-astra/high recommendation, no worker launched.

---

## 2026-09-27 Jev Mario World 6 and campaign ranking (Issue #5561)
Add 6-1..6-4, four musical voices, and one automatic record per play across life retries and stage transitions. Rank by reached course, course cleared, total score, then wall-clock duration, grouped by starting course/controller/power/revision. Keep authenticated self-reported sharing, generated player names, bounded retention and owner-only history. Preserve legacy records. Cloud CI and concrete DB/auth owner review pending before production. No new-course natural AI clear or original ROM/music parity claim. Resource routing CLOUD_REQUIRED; lead frontier/high, no workers.

---

## 2026-09-27: acquisition measurement audit (#5563)
Added a read-only anonymous production measurement audit and actual service transport fault tests. Added finalized Search Console daily collection/validation with timezone and missing-day preservation. See docs/evidence/seo-measurement-20260927/PROTOCOL.md and docs/SEARCH_CONSOLE_MEASUREMENT.md. Google property/authorization and prospective causal evidence remain pending.

---

## 2026-09-27 Jev Mario World 7 and visible campaign ranking (Issue #5565)
Add independent 7-1..7-4, five-voice original arrangements, automatic ranking loading/filter refresh/post-share refresh. Extend course and version constraints only; preserve the approved authenticated automatic sharing model, retention, quotas, pseudonyms and historical records. Cloud tests cover water physics, progression, rescue, audio headroom, ranking responses and denied access. No exact original parity or natural model clear claim. CLOUD_REQUIRED, frontier/high lead, no workers.

---

## 2026-09-27 Acquisition comparison tool (#5563)
- Turn the Zenn measurement findings into a public, browser-only comparison tool: strict daily input, missing-data hold, per-day rates, descriptive control/search comparisons, timezone boundaries, transport-stage reconciliation and JSON export.

- Verify the actual desktop/mobile interface in cloud and production before adding the direct article link. Google live data and prospective causal evidence remain separate incomplete gates; no invented outcomes.

---

## 2026-09-27 World 8 and repeated autoplay failures (Issue #5571)
Add 8-1..8-4, six original pitched voices, bounded live-state collision assistance and per-play failure memory for LightGBM + search. Preserve cumulative campaign ranking, authenticated automatic sharing, retry/lives/items/fireworks and old records. Extend only course/revision limits. Validate delayed worker delivery separately from tree inference and original-game fidelity. CLOUD_REQUIRED, Jev recommends frontier/xhigh; lead execution retained, no local workers or heavy runs.

---

## 2026-09-28 Persistent Mario retry experience (Issue #5576)
Persist capped device-local failure clusters and extend search/collision foresight near repeated failures. This is explicit assistance, not LightGBM retraining. Add useful-item priorities, Luigi palette, red Koopa/Paratroopa behavior and a seventh original musical answer part. Preserve existing campaign sharing and privacy. Validate before/after obstacle progress, reload/clear, mute/audio headroom and desktop/mobile play in cloud. Full natural 32-course clear and exact original parity remain unverified.

---

## 2026-09-28 Measured AI usage comparison (Issue #5574)
- Add browser-only condition comparison of measured token components, request counts and reported model/run costs. Preserve the archived 18-trial provenance; no model calls, telemetry or secret handling.
- Validate invalid input, duplicate trials, model mixing, zero baseline, export and desktop/mobile interactions in cloud. Production verification and article PR82 remain required before completion.

---

## 2026-09-28: Underwater exit and power-up pursuit (#5582)
- Bound the player to the course; stop rewarding progress past underwater exits and value descent near the pipe. Pulse swimming input explicitly.
- Search for reachable power-ups, including block reveals, with a longer horizon. Preserve local retry memory and shared campaign rankings.
- Add a quiet eighth bell part; original synthesized arrangement, not the reference soundtrack.
- Cloud tests cover complete water courses, overshot-exit recovery, pickups and browser/audio regressions; final outcomes are recorded in the PR.

### daily-development セッション記録 (2026-09-28 / Claude Code Win版)

- メインの作業チェックアウトは今回 `fix/asset-ai-card-discipline-reconcile` (origin/main から689コミット遅れ・未コミット2件) だったため触れず、origin/main から独立した worktree (`daily-dev-20260928`) で作業し main へ直接 landing した。
- `/parking` ([lib/pages/parking_reservation_page.dart](../lib/pages/parking_reservation_page.dart)) の「新規予約」ボタンは「新規予約機能は準備中です」と表示するだけだったが、`lifestyle-hub` の `parking.reserve` action はサーバー側に実装済みで、UI からの実行経路だけが欠けた行き止まりだった。駐車場名・区画・開始/終了日時・ナンバー・料金の入力ダイアログを追加して接続し、保存後に一覧を再取得する。
- EF 側は入力を無検証で `hub_data` に保存するため、駐車場名必須・終了>開始・料金0以上の整数の検証を純関数 `ParkingReservationDraft` ([lib/models/parking_reservation_entry.dart](../lib/models/parking_reservation_entry.dart)) に置いた。送信 body を一覧モデル `ParkingReservationEntry` で読み戻す往復テストで、書き込み側と読み取り側のキー不一致を検出できるようにした。
- 駐車場事業者への実予約ではなく「予約内容の記録」であることをダイアログに明記 (成功を装わない)。
- 同種の「サーバー実装済み・UI準備中」候補として `loyalty.redeem` (ポイント交換) と `wallet.pay` (送金) も確認したが、残高を減らす金銭系操作のため今回は着手せず人間レビュー前提で持ち越す。`/meal-log` の AI 栄養推定はサーバー側 (`food_analysis`) が未実装で、UI 文言に内部メモ「Codex#2準備中」が露出している点を次回候補とする。
- 実績は migration `20260928090000_seed_achievements_daily_dev_20260928.sql` に記録。ブログ下書きキューは2030年分まで埋まっているため手動追加は見送り。

### 2026-09-28 支出分類の確信度の説明（#5590）

既存の参考表示を維持し、確信度の読み方を開閉できる説明を追加。確信度1.0の誤分類と候補外応答からの回復を制御した画面試験へ追加した。検証はクラウドCIで実施し、実モデル精度と区別する。本番配信・記事同期は未完了。


### 2026-09-30 ノート検索の待機・競合・回復（#5609）

既存の /ai-search で再検索中も前の結果を検索語付きで維持し、最新要求だけを反映する。クリア・画面破棄後の遅い応答と同一要求の二重送信を防止し、失敗後の再試行を提供。Reactの設計論から非同期表示の境界を学び、Flutterの既存画面へ適用する。制御Futureの画面試験と専用テストentrypointによるデスクトップ・モバイル相当ブラウザ試験をクラウドで実施する。実AI精度や速度向上の主張には使わない。

### 2026-09-30 Jev Mario：9パート音楽と再挑戦時の取得

初期音量を50%へ上げ、短い和音フレーズを加える。停滞記憶でアイテム取得が永久に除外される動作を、現在のプレイ中だけの短時間回避へ修正する。保存済み経験からの取得・クリア、音声・水中・共有ランキングをクラウド検証する。全32面攻略・原作完全一致は未実証。


### 2026-09-30 FLOW CITY統合検証（PR5353）

既存プロトタイプを現行mainへ同期し、ホーム導線・名前付きルート・Web/native表示・破棄処理・widget検査・統合Playwright 3ケースを追加。既存認証・課金・DBは変更しない。利用者の第3弾Claude Code設計確認例外を適用。ホームカタログの取得省略混入を検出して完全原本から修正、クラウド整形も適用。専用モデル・独立画面検査と解析は成功、統合画面・全体CIは継続中。本番・X・有料Jevはこの段階では未操作。

### 2026-09-30 支出意味検索の判定由来と通信回復

- Zennの意味検索記事との対応確認で、通信失敗時の語句一致値がJev由来と表示され、キャッシュに残る経路を発見。失敗した条件を含むアイテムは全条件を語句一致で再評価し、由来をlocal_fallbackとして返す。成功したAPI確率だけをキャッシュする。
- 固定HTTP応答による正常・障害・回復、肯定0.50/除外0.60の境界を検証する。既存の除外テストは支出名でなく質問から応答を選ぶ。クラウドCIの結果はPRへ記録。実モデルの精度・速度の計測ではない。
- 現行lib内に本サービスの画面呼出元は確認できず、公開画面・本番操作・記事の利用導線は未完了。APIキー、認証、DB、課金、画面は変更しない。担当はCodex配下の限定worker、leadはレビューと報告。ローカル依存取得・worktree追加は資源不足により行わない。

---


## Stack

- Frontend: Flutter Web (Dart)
- Backend: Supabase (PostgreSQL + Edge Functions / Deno)
- Hosting: Firebase Hosting
- AI: Claude Code (10 instances) + Codex CLI (2 instances)

Auto-generated by `scripts/build_in_public_extract.py` (= INDIE_DEV_VELOCITY #7 Community Engagement Discipline dogfood).
