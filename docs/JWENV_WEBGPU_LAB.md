# Jwenv WebGPU lab

`web/labs/jwenv/` runs kishida's Jwenv (Qwen3-0.6B fine-tuned to behave like Jev, per the
author's post) inside the browser with WebGPU. It is a read-only experiment next to the BERT comparison in
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

## Saved measurement (run 35694974350)

`web/labs/jwenv/results.json` and `docs/validation/jwenv-lab-20260922/` hold the CI record:
Chromium 140 with the SwiftShader adapter on a 4-vCPU AMD EPYC runner. Model load 1,956 ms;
the article example took 47,435 ms (122 tokens); the 8 candidate logits matched a CPU
recomputation over all 151,936 rows (max abs diff 9.5e-7); Jwenv matched 10 of the 11
referenced memos (rule 9, BERT 10) with a median of 408,405 ms per 12-question request.
The example took over 30 s, so the harness ran the memos once instead of twice. All 26 page
requests went to the loopback server. These are CPU-emulation timings, not GPU timings.

## Decision methods A and B (2026-09-25)

The saved SwiftShader run showed that method A's P(yes) values sit close together (around 0.8)
and its 0.5 threshold flagged none of the three memos written to need review. Method B, the
metrics and the adoption rule were pre-registered in `docs/JWENV_DECISION_METHOD.md` together
with 20 holdout memos (`web/labs/jwenv/holdout.json`) before any run. The page and the harness
now run both methods on the same stage-1 request.

## Measurement suites

- `--suite smoke` (CI `measure` job): Playwright Chromium with SwiftShader, the article example,
  the limit check, one slice check and methods A/B on the first original memo. Functional only;
  its timings are CPU emulation. Output `results-smoke.json`.
- `--suite full --browser chrome` (local real GPU): installed Chrome, headed, all 34 memos with
  both methods. Output `results-gpu.json`, shown in section 05 of the page. The harness refuses
  to start below 4 GiB of free memory (AGENTS.md cloud-first threshold).

```powershell
python scripts/jwenv_lab/run_lab.py download --dest $env:TEMP\jwenv.gguf
python scripts/jwenv_lab/run_lab.py measure --model $env:TEMP\jwenv.gguf --suite full --browser chrome --out out/jwenv-gpu
```
