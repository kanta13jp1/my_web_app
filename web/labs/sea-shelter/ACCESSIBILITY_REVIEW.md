# Sea Shelter accessibility review — 2026-10-30

Scope: compact main screen, construction, residents, requests, farm, profile/help/reset dialogs; desktop1280×720/1366×768 and mobile320×568/360×640/390×844, low landscape height and enlarged text.

## Design plugin status

Not run. The installed Anthropic Design1.2.0 plugin is disabled. A fresh resource snapshot reached86% memory, so repository cloud-first policy prohibits a local AI worker. No plugin settings, external connectors or paid service were enabled. `docs/DESIGN_ACCESSIBILITY_AUDIT.md` makes the plugin review optional, and requires this limitation to be recorded honestly. The deterministic/manual review below is not a completed Design plugin audit or a claim of full WCAG conformance.

## Findings and remediation

- WCAG1.4.11, medium: unselected sea-cell border `#468298` on `#20566a` measured1.89:1. Replaced border with `#8fc4d1`; the candidate browser test measures the rendered border and requires≥3:1.
- Mature harvest double-click previously changed the same control into planting and spent2wood. Distinct, stable plant/harvest buttons now prevent that operation change; unavailable controls remain disabled. Real-browser regression reproduces the old failure and passes after correction.
- WCAG2.4.3: narrow-view keyboard construction now focuses the board after the construction panel is hidden, garden selection focuses its enabled control, and a completed keyboard farm action focuses the result rather than another paid action.
- Long farm-recovery warnings now increase reachable page height when necessary so the44px-minimum board does not overlap tabs, status or collection controls. Normal main screens fit without page scrolling; long panels can scroll internally, and low heights/enlarged text/long warnings may require page scrolling.

## Deterministic/manual evidence

Measured palette ratios: main text15.34:1, secondary text9.47:1, button text11.02:1, button border3.08:1, sea text5.46:1, built-cell text6.62:1, built-cell border3.21:1, primary-button text9.99:1, focus indicator on selected control5.85:1. Browser tests additionally measure actual computed sea/button/primary colors at all5 normal viewports and attach JSON evidence.

Candidate Playwright checks cover44px targets, visible selected/disabled states, keyboard placement and focus, narrow reflow, dialogs and reset cancel/confirm, storage refusal, corrupt-farm recovery, offline timing, mature repeated harvesting, console/page/network errors, and screenshots. Native button labels and `aria-pressed` expose tab selection; the board has coordinate/facility names; status messages use a live region. Profiles render as plain text. No generated images or autoplay media were added. Reduced-motion styling is retained.

Error copy identifies the missing resource and recovery action, explains clock pauses/restarts, and distinguishes farm-only recovery from loss of the shelter. Browser-local saving is explicit; cross-device sync and multi-tab conflict protection are not claimed.

## Not tested / release follow-up

Actual VoiceOver/NVDA/TalkBack, physical iPhone Safari, and actual software-keyboard occlusion are not tested. Owner: Sea Shelter feature maintainer; follow up on physical mobile/AT verification after release. Plugin critique remains optional follow-up. No full WCAG2.1AA certification is claimed.
