// The experimental controller accepts bounded numeric telemetry, never a prompt/ROM.
export const MARIO_ACTIONS = {
  noop: 'Release all controls', right: 'Walk right',
  right_jump: 'Move right and jump', right_run: 'Run right',
  right_run_jump: 'Run right and jump', jump: 'Jump vertically', left: 'Walk left',
};
export class MarioError extends Error {
  constructor(public status: number, public code: string) { super(code); }
}
function invalid(): never { throw new MarioError(400, 'invalid_telemetry'); }
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) invalid();
  return value as Record<string, unknown>;
}
function number(value: unknown, min: number, max: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < min || value > max) invalid();
  return value;
}
export function telemetry(value: unknown) {
  const s = object(value);
  const p = object(s.player);
  if (typeof p.grounded !== 'boolean' || !Array.isArray(s.enemies) || s.enemies.length > 5 ||
    !Array.isArray(s.tiles) || s.tiles.length !== 117) invalid();
  return {
    player: { x: number(p.x, 0, 65535), y: number(p.y, 0, 511),
      vx: number(p.vx, -128, 127), vy: number(p.vy, -128, 127), grounded: p.grounded },
    enemies: s.enemies.map((value) => {
      const e = object(value);
      return { dx: number(e.dx, -65535, 65535), y: number(e.y, 0, 511), type: number(e.type, 0, 255) };
    }),
    // 13 rows, 9 columns: player-centered world columns, tile bytes; -1=unknown.
    tiles: s.tiles.map((v) => number(v, -1, 255)),
    world: number(s.world, 1, 8), stage: number(s.stage, 1, 4),
    previous_response_ms: number(s.previous_response_ms, 0, 10000),
  };
}
export function marioAnswer(value: unknown) {
  const a = value as Record<string, unknown> | null;
  const fail = () => { throw new MarioError(502, 'invalid_provider_response'); };
  if (!a || a.type !== 'choice' || typeof a.choice !== 'string' ||
    !Object.hasOwn(MARIO_ACTIONS, a.choice) || typeof a.confidence !== 'number' ||
    !Number.isFinite(a.confidence) || a.confidence < 0 || a.confidence > 1) return fail();
  const probs = a.probabilities as Record<string, number>;
  if (!probs || Array.isArray(probs) || Object.keys(probs).length !== 7 ||
    Object.keys(MARIO_ACTIONS).some(k => typeof probs[k] !== 'number' || !Number.isFinite(probs[k]) || probs[k] < 0 || probs[k] > 1) ||
    Math.abs(Object.values(probs).reduce((s, v) => s + v, 0) - 1) > 0.01) return fail();
  return { choice: a.choice, confidence: a.confidence, probabilities: probs };
}
export async function decideMario(o: {
  userId: string | null; anonymous: boolean; allowedUsers: string[];
  apiKey: string; body: Record<string, unknown>;
  reserve: (id: string) => Promise<boolean>; fetcher?: typeof fetch; now?: () => number;
}) {
  if (!o.userId || o.anonymous) throw new MarioError(401, 'authentication_required');
  if (!o.allowedUsers.includes(o.userId)) throw new MarioError(403, 'experiment_not_enabled');
  if (o.body.consent !== true) throw new MarioError(400, 'explicit_consent_required');
  const state = telemetry(o.body.state);
  if (!o.apiKey) throw new MarioError(503, 'provider_unconfigured');
  let reserved;
  try { reserved = await o.reserve(o.userId); } catch { throw new MarioError(503, 'quota_unavailable'); }
  if (!reserved) throw new MarioError(429, 'quota_exceeded');
  const now = o.now ?? (() => performance.now());
  const started = now();
  try {
    const r = await (o.fetcher ?? fetch)('https://api.typesafe.ai/v1/systemone', {
      method: 'POST', redirect: 'error', signal: AbortSignal.timeout(3000),
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${o.apiKey}` },
      body: JSON.stringify({ model: 'jev-latest', state, questions: { controller: {
        type: 'choice', criteria: MARIO_ACTIONS,
        instructions: 'Play original Super Mario Bros. Move right toward the flag and avoid enemies and gaps. y increases downward; velocities are signed engine units. tiles are row-major 13x9, starting at y=32, columns from floor(player.x/16)-2. 0 means empty, positive bytes are terrain, -1 unknown. Grounded means player state 0. Simulation continues during request latency. Choose a controller action; do not invent a button. Jump must be released between jumps.',
      } } }),
    });
    if (!r.ok) throw new MarioError(502, 'provider_unavailable');
    const data = await r.json();
    return { ...marioAnswer(data?.answers?.controller),
      upstream_http_ms: Math.max(0, now() - started), model: 'jev-latest' };
  } catch (e) {
    if (e instanceof MarioError) throw e;
    throw new MarioError(502, 'provider_unavailable');
  }
}
