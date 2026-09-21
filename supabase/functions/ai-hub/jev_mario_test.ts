import { decideMario, MARIO_ACTIONS, MarioError, telemetry, marioAnswer } from './jev_mario.ts';
function assert(ok: unknown) { if (!ok) throw new Error('assertion failed'); }
const state = () => ({ player: { x: 160, y: 176, vx: 12, vy: 0, grounded: true }, enemies: [], tiles: Array(117).fill(0), world: 1, stage: 1, previous_response_ms: 0 });
const answer = () => ({ type: 'choice', choice: 'right', confidence: .9,
  probabilities: Object.fromEntries(Object.keys(MARIO_ACTIONS).map(k => [k, k === 'right' ? 1 : 0])) });
function options() {
  return { userId: 'u', anonymous: false, allowedUsers: ['u'], apiKey: 'test-only',
    body: { consent: true, state: state() }, reserve: async () => true,
    fetcher: (async () => new Response(JSON.stringify({ answers: { controller: answer() } }))) as typeof fetch };
}
async function rejects(o: Parameters<typeof decideMario>[0], status: number) {
  try { await decideMario(o); throw new Error('expected rejection'); } catch(e) { assert(e instanceof MarioError && e.status === status); }
}
Deno.test('auth, allowlist, consent and quota fail before provider calls', async () => {
  const o = options(); let calls = 0; o.fetcher = (() => { calls++; throw new Error('unexpected'); }) as typeof fetch;
  await rejects({ ...o, userId: null }, 401);
  await rejects({ ...o, anonymous: true }, 401);
  await rejects({ ...o, allowedUsers: [] }, 403);
  await rejects({ ...o, body: { ...o.body, consent: false } }, 400);
  await rejects({ ...o, reserve: async () => false }, 429);
  await rejects({ ...o, reserve: () => Promise.reject('db') }, 503);
  assert(calls === 0);
});
Deno.test('bounded schema strips arbitrary prompts and rejects non-finite values', async () => {
  assert(!('prompt' in telemetry({ ...state(), prompt: 'anything' })));
  const o = options(); await rejects({ ...o, body: { consent: true, state: { ...state(), tiles: [] } } }, 400);
  await rejects({ ...o, body: { consent: true, state: { ...state(), player: { ...state().player, x: Infinity } } } }, 400);
});
Deno.test('fixed upstream contract and clock excludes reservation time', async () => {
  let clock = 0;
  const result = await decideMario({ ...options(), now: () => clock,
    reserve: async () => { clock += 90; return true; },
    fetcher: (async (url, init) => {
      assert(url === 'https://api.typesafe.ai/v1/systemone');
      const body = JSON.parse(String(init?.body));
      assert(body.questions.controller.type === 'choice' && Object.keys(body.questions.controller.criteria).length === 7);
      assert(init?.redirect === 'error'); clock += 123;
      return new Response(JSON.stringify({ answers: { controller: answer() } }));
    }) as typeof fetch,
  });
  assert(result.upstream_http_ms === 123 && result.choice === 'right');
});
Deno.test('upstream failures, invented actions, NaN, missing scores and invalid sum fail closed', async () => {
  for (const invalid of [{ ...answer(), choice: 'delete' }, { ...answer(), confidence: NaN }, { ...answer(), probabilities: {} }, { ...answer(), probabilities: { ...answer().probabilities, jump: 1 } }]) {
    let failed = false; try { marioAnswer(invalid); } catch { failed = true; } assert(failed);
  }
  await rejects({ ...options(), fetcher: (async () => new Response('secret should not escape', { status: 500 })) as typeof fetch }, 502);
});
