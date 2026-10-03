# Blur Studio

Original CSS comparison inspired by the two still images in Hamad Tanveer's post:
https://x.com/uiux_hamad/status/2097266353212207111

Introduction: https://x.com/marimo_engineer/status/2097595658333282382

Open `/labs/blur-studio/index.html`. Adjust the slider, select a palette, switch
off the effect, then reset. No login, API, external font, analytics, persistence,
or automatic animation. The home link returns to the existing application.

Only the decorative `.art` element is filtered. Text is a sibling, over a white
scrim. The original design-tool value `200` is not a CSS calibration. This is
an independent layout and implementation, not the author's source code.

JavaScript disabled: initial comparison remains visible, with disabled controls
and a visible explanation. CSS filter unsupported: shapes remain visible.
The OS reduced-transparency preference takes precedence over the effect toggle.

Cloud verification: `test/e2e/blur_studio.spec.ts`, Chromium desktop/mobile,
via the existing visual regression workflow. No performance or screen-reader
certification is claimed; human assistive-technology testing remains pending.
