# ひらがなの小庭

Original five-character practice lab, inspired by the use case in https://x.com/omochimetaru/status/2098677091315449944 . The source app's images, audio, code and brand are not reused.

Open `/labs/hiragana-garden/index.html`. Select a character and guided/free mode. Guided mode consumes consecutive 5-unit path samples inside a 24-unit radius; this is path following, not handwriting recognition or educational evaluation. Free ink is bounded to 10,000 input points per reset. Character/mode changes reset all ink. No persistence, API, external fonts, analytics, speech, or third-party dependencies are introduced in this page. Initial delivery still requires loading the static files; this does not make the whole application offline.

Keyboard users can select characters/modes, reset, and toggle numbered path guidance. Drawing itself requires a pointing device. A semantic static guide remains when JavaScript is unavailable.

Checks: `node --test test/hiragana/model.test.mjs`; `npx playwright test test/e2e/hiragana_garden.spec.ts --project=chromium --project=mobile-chrome --workers=1 --retries=0` against the repository SPA server. Device emulation is not physical iPad/Safari validation.
