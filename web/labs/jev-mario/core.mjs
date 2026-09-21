export const ACTIONS = ['noop', 'right', 'right_jump', 'right_run', 'right_run_jump', 'jump', 'left'];
export const BUTTONS = { noop: [], right: [7], right_jump: [7, 0], right_run: [7, 1], right_run_jump: [7, 1, 0], jump: [0], left: [6] };
export const signed = v => v > 127 ? v - 256 : v;
// SMB1 RAM layout, as documented by gym-super-mario-bros and SMB disassembly.
// Only supported NROM SMB1 layout. Unknown/unloaded world columns are marked -1.
export function readState(ram, previous = 0) {
  const x = ram[0x6d] * 256 + ram[0x86];
  const screenLeft = ram[0x71a] * 256 + ram[0x71c];
  const tiles = [];
  for (let row = 0; row < 13; row++) for (let col = -2; col <= 6; col++) {
    const worldCol = Math.floor(x / 16) + col;
    const px = worldCol * 16;
    const known = px >= screenLeft && px < screenLeft + 256 && worldCol >= 0;
    tiles.push(known ? ram[0x500 + (Math.floor(worldCol / 16) % 2) * 208 + row * 16 + worldCol % 16] : -1);
  }
  const enemies = [];
  for (let i = 0; i < 5; i++) if (ram[0xf + i]) enemies.push({
    dx: ram[0x6e + i] * 256 + ram[0x87 + i] - x, y: ram[0xcf + i], type: ram[0x16 + i],
  });
  return { player: { x, y: ram[0xce], vx: signed(ram[0x57]), vy: signed(ram[0x9f]), grounded: ram[0x1d] === 0 },
    enemies, tiles, world: ram[0x75f] + 1, stage: ram[0x75c] + 1,
    previous_response_ms: Math.min(10000, previous) };
}
export function fixture() {
  return { player: { x: 160, y: 176, vx: 12, vy: 0, grounded: true },
    enemies: [{ dx: 64, y: 176, type: 6 }],
    tiles: Array.from({ length: 117 }, (_, i) => i >= 99 ? 84 : 0),
    world: 1, stage: 1, previous_response_ms: 0 };
}
export function summarize(values) {
  const a = values.filter(Number.isFinite).slice().sort((a, b) => a - b);
  if (!a.length) return { count: 0, median: null, p95: null };
  return { count: a.length, median: (a[Math.floor((a.length - 1) / 2)] + a[Math.floor(a.length / 2)]) / 2,
    p95: a[Math.ceil(a.length * .95) - 1] };
}
export function validateRom(bytes) {
  if (bytes.length < 16 || bytes[0] !== 78 || bytes[1] !== 69 || bytes[2] !== 83 || bytes[3] !== 26 ||
    bytes[4] !== 2 || bytes[5] !== 1 || (bytes[6] & 0xf4) !== 0 || bytes[7] !== 0 ||
    bytes.length !== 16 + 32768 + 8192) throw new Error('対応するiNES形式のSMB1 ROM（Mapper 0、32KB PRG / 8KB CHR）を選んでください。');
}
export class DecisionLoop {
  constructor({ request, state, apply, record, done, clock = () => performance.now(), schedule = (fn, ms) => setTimeout(fn, ms), cancel = id => clearTimeout(id) }) {
    Object.assign(this, { request, state, apply, record, done, clock, schedule, cancel });
    this.generation = 0; this.active = false; this.pending = false;
  }
  start({ count = 20, duration = 60000, cadence = 200, maxAge = 750 } = {}) {
    if (this.pending) return false;
    this.stop(); this.active = true; this.limit = count; this.deadline = this.clock() + duration;
    this.cadence = cadence; this.maxAge = maxAge; this.attempts = 0;
    this.expiry = this.schedule(() => this.stop('時間上限で停止'), duration);
    this.tick(this.generation); return true;
  }
  stop(reason = '停止') {
    const wasActive = this.active;
    if (wasActive && this.pending) this.record({ ok: false, cancelled: true,
      rtt_ms: this.clock() - this.requestStarted, error: '停止時に応答待ち。サーバー側で課金済みの可能性があります。' });
    this.active = false; this.generation++; this.cancel(this.timer); this.cancel(this.expiry);
    this.apply('noop'); if (wasActive) this.done(reason);
  }
  async tick(generation) {
    if (!this.active || this.generation !== generation) return;
    const started = this.clock(); this.requestStarted = started; this.pending = true; this.attempts++;
    try {
      const answer = await this.request(this.state());
      const rtt = this.clock() - started;
      if (!this.active || this.generation !== generation) return;
      if (!ACTIONS.includes(answer.choice) || !Number.isFinite(answer.upstream_http_ms) || answer.upstream_http_ms < 0 ||
          !Number.isFinite(answer.confidence) || answer.confidence < 0 || answer.confidence > 1) throw new Error('Jev応答の形式が不正です');
      const stale = rtt > this.maxAge;
      this.apply(stale ? 'noop' : answer.choice);
      this.record({ ok: true, rtt_ms: rtt, observation_to_input_ms: this.clock() - started,
        ...answer, stale, applied: !stale });
    } catch (error) {
      if (this.active && this.generation === generation) {
        this.record({ ok: false, rtt_ms: this.clock() - started, error: String(error.message ?? error) });
        this.pending = false;
        this.stop(String(error.message ?? error));
      }
    } finally { this.pending = false; }
    if (!this.active || this.generation !== generation) return;
    if (this.attempts >= this.limit || this.clock() >= this.deadline) return this.stop('測定完了');
    this.timer = this.schedule(() => this.tick(generation), Math.max(0, this.cadence - (this.clock() - started)));
  }
}
