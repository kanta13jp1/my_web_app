// Independent, temporary training state. No settlement or persistence imports.
export const RULES = Object.freeze({
  playerHp: 5,
  targetHp: 60,
  attackCooldown: 1250,
  attackImpact: 180,
  guardDuration: 1150,
  guardCooldown: 1600,
  enemyPeriod: 4800,
  telegraph: 1200,
  assistedTelegraph: 1800,
  specialImpact: 420,
  specialCooldown: 1800,
  specialDamage: 7,
});

export function newTraining({ assisted = false } = {}) {
  return {
    status: "running",
    time: 0,
    assisted: assisted === true,
    playerHp: RULES.playerHp,
    targetHp: RULES.targetHp,
    charge: 0,
    nextAttackAt: 0,
    nextGuardAt: 0,
    guardUntil: -1,
    guardStarted: -1,
    nextStrikeAt: RULES.enemyPeriod,
    telegraphing: false,
    pending: null,
    counterUntil: -1,
    attacks: 0,
    guards: 0,
    specials: 0,
    hitsTaken: 0,
    sequence: 0,
  };
}

const result = (state, events = [], message = "") => ({
  state,
  events,
  message,
});
function emit(state, events, type, detail = {}) {
  events.push({ id: ++state.sequence, time: state.time, type, ...detail });
}
const tellLength = (s) =>
  s.assisted ? RULES.assistedTelegraph : RULES.telegraph;

export function trainingCommand(state, command) {
  if (command === "stop") {
    if (state.status === "stopped") return result(state);
    return result({ ...state, status: "stopped", pending: null });
  }
  if (command === "pause" && state.status === "running") {
    return result({ ...state, status: "paused" });
  }
  if (command === "resume" && state.status === "paused") {
    return result({ ...state, status: "running" });
  }
  if (state.status !== "running") return result(state);
  const s = { ...state }, events = [];
  if (command === "guard") {
    if (s.time < s.nextGuardAt) {
      return result(state, [], "ガードの構え直しを待とう");
    }
    s.guardStarted = s.time;
    s.guardUntil = s.time + RULES.guardDuration;
    s.nextGuardAt = s.time + RULES.guardCooldown;
    emit(s, events, "guard-start");
  } else if (command === "attack" || command === "special") {
    if (s.time < s.nextAttackAt || s.pending) return result(state);
    if (command === "special" && s.charge < 100) {
      return result(state, [], "予告を見てガードすると必殺ゲージがたまる");
    }
    const special = command === "special";
    const counter = !special && s.time <= s.counterUntil;
    s.pending = {
      type: command,
      at: s.time + (special ? RULES.specialImpact : RULES.attackImpact),
      damage: special ? RULES.specialDamage : counter ? 2 : 1,
    };
    s.nextAttackAt = s.time +
      (special ? RULES.specialCooldown : RULES.attackCooldown);
    if (special) {
      s.charge -= 100;
      s.specials++;
    } else {
      s.attacks++;
      s.counterUntil = -1;
    }
    emit(s, events, special ? "special-start" : "attack-start", { counter });
  } else return result(state);
  return result(s, events);
}

// The host feeds bounded foreground frame deltas; hidden time never skips cues.
// Large/invalid deltas are rejected, rather than resolving unseen enemy strikes.
export function advanceTraining(state, milliseconds) {
  if (
    state.status !== "running" || !Number.isFinite(milliseconds) ||
    milliseconds <= 0 || milliseconds > 100
  ) return result(state);
  const end = state.time + milliseconds;
  const s = { ...state }, events = [];
  while (s.status === "running") {
    const tellAt = s.nextStrikeAt - tellLength(s);
    const next = Math.min(
      s.pending?.at ?? Infinity,
      s.telegraphing ? s.nextStrikeAt : tellAt,
    );
    if (next > end) break;
    s.time = next;
    // Ties resolve player impact first. A winning hit cannot take posthumous damage.
    if (s.pending && s.pending.at === next) {
      const impact = s.pending;
      s.pending = null;
      s.targetHp = Math.max(0, s.targetHp - impact.damage);
      s.charge = Math.min(100, s.charge + (impact.type === "attack" ? 4 : 0));
      emit(s, events, "target-hit", {
        damage: impact.damage,
        special: impact.type === "special",
      });
      if (s.targetHp === 0) {
        s.status = "won";
        emit(s, events, "win");
        break;
      }
    }
    if (!s.telegraphing && tellAt === next) {
      s.telegraphing = true;
      emit(s, events, "enemy-tell", { duration: tellLength(s) });
    } else if (s.telegraphing && s.nextStrikeAt === next) {
      const guarded = s.guardUntil >= s.time && s.guardStarted >= tellAt;
      if (guarded) {
        s.guards++;
        s.counterUntil = s.time + 1500;
        s.charge = Math.min(100, s.charge + 22);
        emit(s, events, "guard-success");
      } else {
        s.playerHp--;
        s.hitsTaken++;
        emit(s, events, "player-hit");
      }
      s.telegraphing = false;
      s.nextStrikeAt += RULES.enemyPeriod;
      if (s.playerHp === 0) {
        s.status = "lost";
        s.pending = null;
        emit(s, events, "lose");
      }
    }
  }
  if (s.status === "running") s.time = end;
  return result(s, events);
}
