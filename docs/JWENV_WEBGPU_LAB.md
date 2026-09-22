# Jwenv WebGPU lab

`web/labs/jwenv/` runs kishida's Jwenv (a Jev-compatible classifier on Qwen3-0.6B) inside
the browser with WebGPU. It is a read-only experiment next to the BERT comparison in
`web/labs/expense-comparison/` and uses the same 14 synthetic memos and 12 categories.

## What the page does

1. Reports whether WebGPU and an adapter are available.
2. Loads a GGUF file that the user selects locally. Nothing is downloaded automatically;
   the page links to the pinned model (`kishida/jwenv-0.6b-poc-gguf`,
   `jwenv-0.6b-poc-q8_0.gguf`, 639,446,848 bytes, revision `fd39b70`).
3. Runs four checks:
   - the request example printed in the Zenn article (4-option `choice`);
   - the 14 memos × 12 categories, asked as 12 `noul` (yes/no) questions per memo in one
     request, because `choice` accepts at most 8 options; the highest P(yes) becomes the
     candidate and a winner below 0.5 is marked 要確認;
   - one `choice` with all 12 categories, which the vendored validator rejects
     (`too_many_options`, status 422) — this works without a model;
   - the lm_head slice: the final hidden state is dumped, every vocabulary row is
     recomputed on the CPU, and the 8 candidate logits are compared with the GPU result.
4. Shows the saved CI measurement from `results.json` when it exists.

No memo, result or model byte leaves the device. No category is applied to real records.

## Engine and model provenance

- Engine: `kishida/jwenv-demo` revision `8263b814fde5ca11e47718a7ac82945639c02d8d`, copied
  unmodified to `web/labs/jwenv/vendor/jwenv-8263b81/` (MIT; see `NOTICE.md`,
  `manifest.json`). The browser demo imports `dist/src/`, not `dist/qwen3-engine/src/`;
  the two differ in the prompt template (English in `dist/src/jev.js`).
- Model: Apache-2.0, base model Qwen/Qwen3-0.6B per its model card.

## Verification

`.github/workflows/jwenv-webgpu-lab.yml`:

- `contract`: vendored files match `manifest.json`; the model is pinned by revision, size
  and SHA-256; the page loads only same-origin code; request builders pass the upstream
  validator (`node --test scripts/jwenv_lab/core.test.mjs`); black-box browser checks
  without a GPU (`test/e2e/jwenv_lab.py`: normal, wrong file, broken GGUF, retry, missing
  or malformed saved record, unavailable reference data, 390px width).
- `measure`: downloads the pinned GGUF, verifies size and SHA-256, and drives the page in
  Chromium with software WebGPU (SwiftShader) on a CPU runner via
  `scripts/jwenv_lab/run_lab.py`. It uploads `results.json`, screenshots and the browser
  console. The job is skipped when the committed `results.json` matches the current inputs.

## Not verified here

- Timing on a real GPU (CI runners have none); SwiftShader timings are CPU emulation.
- Offline start, and model download time from Hugging Face in a browser.
- Accuracy beyond the 14 synthetic memos; P(yes) values are not calibrated probabilities
  of the category being correct and do not sum to 1 across categories.
