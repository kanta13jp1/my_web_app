export const CROSSINGS = [8, 16, 24];
export const LIMIT = 720;
export const BASE = Object.freeze({ green: 18, offset: 0, demand: 60, seed: 42 });
export function validate(input) {
  if (!input || typeof input !== 'object') throw new Error('設定がありません');
  for (const [key, min, max] of [['green', 6, 30], ['offset', 0, 16], ['demand', 20, 80], ['seed', 1, 9999]]) {
    if (!Number.isInteger(input[key]) || input[key] < min || input[key] > max) throw new Error(`設定が不正です: ${key}`);
  }
  return Object.fromEntries(Object.keys(BASE).map(key => [key, input[key]]));
}
export function schedule(config) {
  const c = validate(config); let seed = c.seed;
  const random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
  const events = [];
  for (let tick = 0; tick < 480; tick += 2) {
    if (random() * 100 < c.demand) events.push({ id: events.length, due: tick, axis: random() < .7 ? 'E' : 'S', lane: Math.floor(random() * 3) });
  }
  return events;
}
export function position(car, next = false) {
  const progress = car.p + (next ? 1 : 0);
  return car.axis === 'E' ? [progress, CROSSINGS[car.lane]] : [CROSSINGS[car.lane], progress];
}
export function signal(config, tick, x, y) {
  const phase = ((tick - CROSSINGS.indexOf(x) * config.offset) % 40 + 40) % 40;
  return phase < config.green ? 'E' : phase >= config.green + 2 && phase < 38 ? 'S' : '-';
}
export function create(config) {
  const c = validate(config);
  return { config: c, events: schedule(c), next: 0, tick: 0, pending: [], cars: [], arrived: 0, waiting: 0, travel: 0, history: [] };
}
export function step(world) {
  if (world.tick >= LIMIT) return world;
  while (world.next < world.events.length && world.events[world.next].due <= world.tick) world.pending.push({ ...world.events[world.next++], p: 0 });
  const occupied = new Set(world.cars.map(car => position(car).join(',')));
  const remaining = [];
  for (const car of world.cars) {
    const current = position(car).join(',');
    const [x, y] = position(car, true); const target = `${x},${y}`;
    if (car.p === 32) { occupied.delete(current); world.arrived++; world.travel += world.tick - car.due; continue; }
    const crossing = CROSSINGS.includes(x) && CROSSINGS.includes(y);
    if (!occupied.has(target) && (!crossing || signal(world.config, world.tick, x, y) === car.axis)) {
      occupied.delete(current); occupied.add(target); car.p++; car.stopped = false;
    } else { world.waiting++; car.stopped = true; }
    remaining.push(car);
  }
  const outside = [];
  for (const car of world.pending) {
    const key = position(car).join(',');
    if (!occupied.has(key)) { occupied.add(key); remaining.push(car); } else { outside.push(car); world.waiting++; }
  }
  world.cars = remaining; world.pending = outside; world.tick++;
  if (world.tick % 10 === 0) world.history.push({ tick: world.tick, arrived: world.arrived });
  return world;
}
export function metrics(w) {
  return { tick: w.tick, generated: w.next, arrived: w.arrived, onRoad: w.cars.length, outside: w.pending.length, waiting: w.waiting,
    averageTravel: w.arrived ? w.travel / w.arrived : null };
}
