// node scripts/jwenv_lab/merge_shards.mjs <shard-dir> <out.json>
// Joins results-shard-*.json from the cloud evaluation into one schema-2 record and computes the
// pre-registered metrics with the page's own functions (web/labs/jwenv/core.mjs).
import { readFileSync, readdirSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = fileURLToPath(new URL('../../', import.meta.url));
const lab = join(root, 'web/labs/jwenv');
const core = await import(pathToFileURL(join(lab, 'core.mjs')));
const [dir, outPath] = process.argv.slice(2);
if (!dir || !outPath) throw Error('usage: merge_shards.mjs <shard-dir> <out.json>');

const read = (p) => JSON.parse(readFileSync(p, 'utf8'));
const reference = read(join(root, 'web/labs/expense-comparison/results.json'));
const holdout = read(join(lab, 'holdout.json'));
const order = [...reference.samples.map((s) => s.id), ...holdout.samples.map((s) => s.id)];

const shards = readdirSync(dir).filter((f) => /^results-shard-\d+\.json$/.test(f)).map((f) => read(join(dir, f)));
if (!shards.length) throw Error(`no shard records in ${dir}`);
const of = shards[0].of;
const same = (key) => new Set(shards.map((s) => JSON.stringify(s[key]))).size === 1;
for (const key of ['of', 'inputs_sha256', 'app_revision', 'model', 'engine']) {
  if (!same(key)) throw Error(`shards disagree on ${key}`);
}
const indices = shards.map((s) => s.shard).sort((a, b) => a - b);
const missing = Array.from({ length: of }, (_, i) => i).filter((i) => !indices.includes(i));
if (missing.length || indices.length !== of) throw Error(`missing shards: ${missing.join(',')} (have ${indices.length}/${of})`);

const byId = new Map();
for (const s of shards) {
  for (const row of s.rows) {
    if (byId.has(row.id)) throw Error(`duplicate row ${row.id}`);
    byId.set(row.id, row);
  }
}
const absent = order.filter((id) => !byId.has(id));
if (absent.length || byId.size !== order.length) throw Error(`rows missing: ${absent.join(',')}`);
const rows = order.map((id) => byId.get(id));

const sets = ['original', 'holdout'];
const summary = Object.fromEntries(sets.map((set) => [set, core.summarizeMethods(rows.filter((r) => r.set === set))]));
const external = [...new Set(shards.flatMap((s) => s.network.external_requests))];
const adapters = [...new Set(shards.map((s) => s.environment.adapter))];
const first = shards.find((s) => s.shard === 0);

const record = {
  schema_version: 2,
  suite: 'cloud-shards',
  synthetic: true,
  mode: 'saved_browser_webgpu_measurement',
  recorded_at: shards.map((s) => s.recorded_at).sort().at(-1),
  run_id: first.run_id,
  app_revision: first.app_revision,
  inputs_sha256: first.inputs_sha256,
  engine: first.engine,
  model: first.model,
  environment: {
    adapter: adapters.join(' | '),
    browser: first.environment.browser,
    flags: first.environment.flags,
    runners: [...new Set(shards.map((s) => s.environment.runner?.cpu_model).filter(Boolean))],
    jobs: of,
    headless: first.environment.headless,
  },
  timing_scope: 'One GitHub Actions job per memo, software WebGPU (SwiftShader) on CPU runners. Stage ms cover one '
    + 'JevClassifier.systemOne call each. Not a GPU measurement; runners differ in speed.',
  network: { requests: shards.reduce((a, s) => a + s.network.requests, 0), external_requests: external },
  load_ms: core.median(shards.map((s) => s.load_ms)),
  // The page's saved-record view expects these fields; the shards do not rerun them (see results-smoke.json).
  article_example: null,
  methods: {
    method_doc: 'docs/JWENV_DECISION_METHOD.md',
    thresholds: { a_p_yes: core.NOUL_THRESHOLD, b_choice: core.CHOICE_MAJORITY },
    stage2: { options: core.STAGE2_OPTIONS, permutations: core.STAGE2_PERMUTATIONS },
    rows,
    summary,
    adoption: core.adoptionCheck(summary.holdout),
    timing: {
      stage1_median_ms: core.median(rows.map((r) => r.stage1_ms)),
      stage2_median_ms: core.median(rows.map((r) => r.stage2_ms)),
    },
  },
  shards: shards.sort((a, b) => a.shard - b.shard).map((s) => ({
    shard: s.shard, sample_ids: s.sample_ids, recorded_at: s.recorded_at, load_ms: s.load_ms,
    cpu_model: s.environment.runner?.cpu_model ?? null,
  })),
};
if (external.length) throw Error(`external requests during evaluation: ${external.join(', ')}`);

mkdirSync(dirname(outPath), { recursive: true });
writeFileSync(outPath, `${JSON.stringify(record, null, 2)}\n`);
console.log(JSON.stringify({ summary, adoption: record.methods.adoption, timing: record.methods.timing, adapters }, null, 2));
