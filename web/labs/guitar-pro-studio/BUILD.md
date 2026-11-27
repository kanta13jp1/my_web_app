# Reproducible Guitar Pro / SMuFL Lab Delivery

This lab packages `@coderline/alphatab@1.9.0` (MPL-2.0) post-build without checking binaries (`.woff2`, `.sf3`, minified bundles) into Git.

## Build & Verify

```bash
npm ci --ignore-scripts
node scripts/build_guitar_pro_lab.mjs build/guitar-pro-preview --standalone
node scripts/verify_guitar_pro_lab.mjs build/guitar-pro-preview
```

## Bundled Components & Attribution

- `@coderline/alphatab` `1.9.0` (`MPL-2.0`): `alphaTab.min.mjs`, `alphaTab.core.min.mjs`, `alphaTab.worker.min.mjs`, `alphaTab.worklet.min.mjs` (`vendor/LICENSE.txt`)
- SMuFL Font `Bravura.woff2` (`SIL OFL-1.1`): `vendor/font/Bravura-OFL.txt`
- SoundFont `sonivox.sf3` (`Apache-2.0`): `vendor/soundfont/LICENSE.txt`
- The rendered `♪ alphaTab.net` score attribution must remain visible.
