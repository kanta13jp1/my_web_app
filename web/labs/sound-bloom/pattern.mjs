export const TRACKS = [
  { name: '雫', color: '#8fffe0', note: 72, wave: 'sine' },
  { name: '光', color: '#ffce8b', note: 67, wave: 'triangle' },
  { name: '根', color: '#c6a6ff', note: 48, wave: 'sine' },
  { name: '鼓動', color: '#ff8bb5', note: 36, wave: 'sine' },
];
const masks = [
  [0x9129, 0x0444, 0x0101, 0x1111],
  [0x5555, 0x9292, 0x0505, 0x1111],
  [0xa529, 0x4a4a, 0x4141, 0x5555],
];
export function preset(index = 0) {
  if (!Number.isInteger(index) || index < 0 || index >= masks.length) throw new Error('Unknown preset');
  return { version: 1, tempo: [88, 112, 136][index], muted: [false, false, false, false],
    notes: masks[index].map(mask => Array.from({ length: 16 }, (_, s) => Boolean(mask & (1 << s)))) };
}
export function validate(value) {
  if (!value || value.version !== 1 || !Number.isInteger(value.tempo) || value.tempo < 60 || value.tempo > 160 ||
      !Array.isArray(value.notes) || value.notes.length !== 4 ||
      !value.notes.every(row => Array.isArray(row) && row.length === 16 && row.every(v => typeof v === 'boolean')) ||
      !Array.isArray(value.muted) || value.muted.length !== 4 || !value.muted.every(v => typeof v === 'boolean')) {
    throw new Error('構成ファイルが正しくありません。');
  }
  return { version: 1, tempo: value.tempo, notes: value.notes.map(row => [...row]), muted: [...value.muted] };
}
export function toggle(state, track, step) {
  if (!Number.isInteger(track) || track < 0 || track > 3 || !Number.isInteger(step) || step < 0 || step > 15) throw new RangeError('Invalid cell');
  const next = validate(state); next.notes[track][step] = !next.notes[track][step]; return next;
}
export function frequency(track, step) {
  const scale = [0, 2, 4, 7, 9, 7, 4, 2];
  const midi = TRACKS[track].note + (track < 2 ? scale[step % 8] : 0);
  return 440 * 2 ** ((midi - 69) / 12);
}
export function activeAt(state, step) {
  return state.notes.flatMap((row, t) => row[step] && !state.muted[t] ? [t] : []);
}
