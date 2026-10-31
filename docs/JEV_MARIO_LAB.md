# Jev Mario Lab

## ROM-free World 1-1 reconstruction (#5468)

The default mode is an independently authored browser reconstruction. Manual play needs neither a ROM nor an API call. Arrows move, Space/X jumps (hold for height), Z runs/fires after a flower, Down enters the fourth pipe. Touch buttons also support movement, jump and run. Restart restores the level. Consent and the Jev start button use the existing authenticated decision loop.

Includes the opening blocks, pipes, pits, platforms, staircases, flag/castle, enemies, stomping, power-ups, hidden life and underground coins. Pixel graphics are drawn in code. No ROM, sprite sheet, original program or sound recording is included. Physics, art, timings and placements are approximate; sound and the original death/flag cutscenes are not reproduced.

Exports identify `independent-world11-v1` separately from JSNES and fixed-state measurements. Browser tests use a simulated Jev bridge. Level sequence reference: https://www.mariowiki.com/World_1-1_%28Super_Mario_Bros.%29

Route: `/jev-mario-lab` (home tool catalog: **Jev Mario Lab**).

## Use

1. Sign in to my_web_app and open Jev Mario Lab. In the default reconstruction mode, press the local play button for manual play. Manual play makes no Jev requests; server allowlisting is needed only for Jev measurement.
2. Keep reconstruction mode for live gameplay decisions, or select **固定状態のAPI測定** to send a synthetic numeric state. Fixed-state mode is not a gameplay test.
3. Choose 20/100/300 maximum calls and 200/500/1000 ms minimum cadence. Check consent and start. Every run stops within 60 seconds; failures stop instead of silently substituting rules. A stopped in-flight request may still consume server/API usage.
4. With your own usable original SMB1 iNES ROM (NROM, 32KB PRG, 8KB CHR), select game mode and load it locally. No ROM is provided, fetched or uploaded. Start manually with Enter and reach an active World 1-1 scene; then start Jev. X jumps, Z runs, arrows move in manual mode. ROM layout validation does not prove game identity; hacks and other games are unsupported.
5. Stop or switch away to release controls. Save JSON for individual observations. No measurements/ROMs are persisted remotely by this feature; exports stay under your control.

## Meaning of the measurements

- Browser RTT: state capture through the Flutter bridge, authenticated Edge Function, quota RPC, Jev and response decoding.
- Upstream HTTP: server fetch start through Jev response body decoding. Includes network and service overhead, **not pure model inference**.
- Observation to input: browser state capture until applying controls, only successful non-stale game decisions. Fixed-state mode has no actual gameplay metric.
- Median and nearest-rank p95 include the first/cold request. Failed and cancelled attempts are counted separately from successful latency samples. Responses older than 750 ms are recorded but not applied.
- Emulator advances at nominal 60 Hz while awaiting Jev (no await inside frame loop); rendering throttling and slow machines can still reduce simulated speed. This is a browser measurement, not a guarantee of 60 FPS or of completing the level. Last controls remain held until next decision or stop.
- One outstanding decision; late replies after stop/reset/navigation cannot reapply controls. One run <=300 requests/60 seconds. A new run cannot start until a pending reply finishes/times out. Errors stop immediately, without retries.

## Server activation — owner review required

The shipped action is disabled unless the verified account UUID appears in `JEV_MARIO_USER_IDS` (comma-separated). It uses existing server-only `JEV_API_KEY` and `mario.jev_decide` in ai-hub. No key enters Flutter or the iframe; only typed numeric telemetry and decisions cross the origin/source-checked bridge. Offline mode remains blocked.

After the owner reviews the auth/quota change, apply `20260921051931_jev_mario_quota.sql`, deploy ai-hub, and set the allowed UUID(s) through the existing secret-management workflow. Empty/remove `JEV_MARIO_USER_IDS` to disable. Do not put IDs or keys in this document or public CI.

The RPC reuses the private quota table under separate `mario:` scopes and a separate advisory lock. It is service_role-only, invoker security with empty search_path. Anonymous and non-allowlisted callers fail before provider/DB reservation. Failed upstream calls consume a reservation. Defaults: **300/user/minute, 1000/user/day, 3000/global/day** (UTC fixed buckets; burst across bucket boundaries possible). These are request caps, not monetary billing caps. Expense classification limits remain unchanged.

## Validation and limits

Cloud workflow `Jev Mario lab` runs pure controller/measurement tests, a synthetic non-Nintendo test ROM on JSNES, server auth/schema/provider tests, concurrent SQL quota tests and desktop/mobile Playwright with a simulated message bridge. Browser screenshots are explicitly **fixture evidence**, not live Jev/SMB1 evidence.

Required before claiming end-to-end production use: cloud Flutter analysis/build, owner review/activation, signed-in live API benchmark, and a live recreation gameplay run. Original-ROM compatibility additionally requires an SMB1 ROM gameplay run supplied by the user. At implementation time the user has no ROM, so real SMB1 state parsing and performance remain unverified. The source demonstration's completion/latency numbers are not results for this app.

## Sources and licenses

- Inspiration only (implementation not copied): https://github.com/fhshaik/typesafe-mario
- Emulator: https://github.com/bfirsh/jsnes/tree/v2.1.0 — Apache-2.0; pinned distribution from https://unpkg.com/jsnes@2.1.0/dist/jsnes.min.js and license in `web/jev-mario-lab/vendor/`. No CDN runtime requests.
- RAM address references: https://github.com/Xkeeper0/smb1/blob/master/src/ram.asm and https://github.com/Kautenja/gym-super-mario-bros/blob/master/gym_super_mario_bros/smb_env.py . Only numeric address facts used; no ROM, graphics, disassembly implementation or third-party control logic copied.
- Current API shape follows existing validated Jev expense integration: `/v1/systemone`, `model/state/questions`, choice `criteria`, answer `answers.controller`.

Self-review: native labels, keyboard focus rings, 44px buttons, live status/error text, responsive single column under 700px, explicit sending consent and actionable errors. No generated imagery. Optional Anthropic Design plugin review not run. Screen-reader and live authenticated Flutter iframe integration still require verification.

## Direct navigation and iframe assets

The public Flutter route is `/jev-mario-lab`. The isolated game document is `/labs/jev-mario/index.html`; never place a static directory index at the Flutter route, because Firebase serves that file before the SPA rewrite. The iframe must remain inside the app for its authenticated message bridge. Verify direct navigation and refresh as well as in-app navigation after release.

## Response age and network failures

Choose a response age limit of 750, 1,500 (default), or 3,000 ms before starting. A reply slower than that remains a successful API timing sample but is discarded for gameplay, with an explanation beside the metrics. Exported JSON includes `max_age_ms`. A larger limit allows older decisions; it does not reduce latency or pause the game. Changing the limit stops the run. A 502 stops measurement and releases controls; it may be a provider/network failure or invalid response, so it is not treated as a successful decision or automatically retried.

## BGM・効果音

ROM不要の再現ゲームで「音声をONにする」を選び、手動またはJev操作を開始します。音量は0〜100%（初期25%）、チェック解除でミュートできます。オリジナルの合成BGMとジャンプ・コイン・ブロック・アイテム・踏みつけ・ダメージ・土管・ミス・クリアSEをブラウザ内で生成します。地下ではBGMの音域が変わります。原作の音源は同梱していません。停止・モード変更・画面離脱で停止し、固定状態測定とROMモードは無音です。


## Prediction input comparison (2026-09-22)

The recreation exposes an opt-in `prediction_v1` input profile. Baseline remains the default. Select the input profile before starting, reset to the same initial state, and keep controller/cadence/recording settings equal. The exported metadata records `input_profile`; each provider reply echoes the sanitized profile. Prediction includes bounded constant-velocity estimates at 60 simulation Hz, previous browser RTT (1000ms initially), current jump/run state, nearby enemy speed/gap, time to contact and projected gap. It does not compensate latency, simulate terrain, or establish improved Jev performance. Auth, allowlist, explicit consent and quota are unchanged. ROM/fixture modes keep baseline.

The supplied course-1 run is Jev-only: `right`, `right`, `right_run`, three applied answers, zero stale/failures and one pending cancellation. At the third arrival (frame178), gap119.02px; collision at frame218/x308.26 while the next reply was pending. Tests replay this state separately from live API evaluation.

Local assistance now preserves running intent through jump/landing release. Item emergence lasts16 simulation frames before movement/collection, reversal produces one skid sound per braking episode, and the original soundtrack has distinct25%/50% pulse voices. This is an independent reconstruction, not an original ROM or sampled soundtrack.


## Feedback revision (2026-09-22)

Jump held at stomp contact produces a higher rebound; scores float after stomps and powerups. Fireballs hit at most one enemy, wall impacts render a short burst and original synthesized SE. Effects briefly lower the original BGM channel without lowering effect or recording volume. No original soundtrack is bundled. Stale Jev replies still release controls; local assistance only acts on rightward intent. This does not solve real-time latency or demonstrate a clear.
