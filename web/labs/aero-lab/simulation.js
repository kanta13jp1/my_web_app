/**
 * A normalized, fictional teaching model. These outputs are relative visual
 * indicators, not temperatures, engine specifications, or operational advice.
 */
const clamp = (value, fallback = 0) => {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(1, Math.max(0, number)) : fallback;
};
const round = (value) => Math.round(value * 10) / 10;

/** @param {{throttle?: number, fault?: boolean | number}} [input] */
export function deriveMetrics({ throttle = 0.62, fault = false } = {}) {
  const power = clamp(throttle, 0.62);
  const severity = clamp(fault);
  const spool = 18 + 82 * Math.sqrt(power);
  const nominalThrust = 100 * power ** 1.42;
  const nominalHeat = 14 + 66 * power ** 0.78;
  const efficiency = 36 + 55 * (1 - Math.exp(-3.2 * power)) - 9 * power ** 4;
  return Object.freeze({
    thrustPercent: round(nominalThrust * (1 - 0.42 * severity)),
    spoolPercent: round(spool * (1 - 0.08 * severity)),
    temperatureIndex: round(Math.min(100, nominalHeat + (8 + 12 * power) * severity)),
    efficiencyPercent: round(efficiency * (1 - 0.3 * severity)),
    status: severity > 0.01 ? 'degraded' : power < 0.1 ? 'idle' : power > 0.86 ? 'high-power' : 'nominal',
  });
}

