// Explicit clone-based escape assistance; never learned inference or a world rewind.
import {clone, advance} from './search-assist.mjs?v=student-1';

const ACTIONS = new Set(['right_run', 'right_run_jump']);
export function normalizeEscapeSequence(value) {
  if (!Array.isArray(value) || !value.length || value.length > 3) return null;
  let total = 0;
  const result = [];
  for (const command of value) {
    if (!command || !ACTIONS.has(command.action) || !Number.isInteger(command.frames) ||
        command.frames < 1 || command.frames > 60) return null;
    total += command.frames;
    if (total > 80) return null;
    result.push({action: command.action, frames: command.frames});
  }
  return result;
}

export function escapeOriginMatches(g, origin) {
  return !!origin && g.phase === 'playing' && g.stage === origin.stage &&
    g.room === origin.room && g.power === origin.power && g.lives === origin.lives &&
    Number.isInteger(origin.frame) && g.frames >= origin.frame &&
    g.frames - origin.frame <= 60 && Number.isFinite(origin.x) &&
    Math.abs(g.p.x - origin.x) <= 48;
}

export function evaluateEscapeSequence(g, value) {
  const commands = normalizeEscapeSequence(value);
  if (!commands || g.phase !== 'playing') return null;
  const simulated = clone(g);
  for (const command of commands) {
    // Check damage on every frame, not just the endpoint where a pickup could hide it.
    for (let i = 0; i < command.frames; i++) {
      advance(simulated, command.action, 1);
      if (simulated.phase !== 'playing' || simulated.stage !== g.stage ||
          simulated.room !== g.room || simulated.power < g.power || simulated.lives < g.lives)
        return null;
    }
  }
  return {progress: simulated.p.x - g.p.x, grounded: simulated.p.grounded};
}

export function findEscapeSequence(g, failures = []) {
  if (g.phase !== 'playing' || g.room !== 'castle') return null;
  const repeated = failures.some(r => r.stage === g.stage && r.room === g.room &&
    r.kind === 'stalled' && r.count >= 2 && Number.isFinite(r.x) &&
    g.p.x >= r.x - 48 && g.p.x <= r.x + 24 &&
    ((r.failedActions?.jump ?? 0) + (r.failedActions?.noop ?? 0)) > 0);
  if (!repeated) return null;
  let best = null;
  for (let approach = 0; approach <= 8; approach++) {
    for (let held = 1; held <= 12; held++) {
      const commands = [...(approach ? [{action: 'right_run', frames: approach}] : []),
        {action: 'right_run_jump', frames: held}, {action: 'right_run', frames: 60}];
      const outcome = evaluateEscapeSequence(g, commands);
      if (!outcome?.grounded || outcome.progress < 48) continue;
      if (!best || outcome.progress > best.progress) best = {commands, ...outcome};
    }
  }
  return best;
}
