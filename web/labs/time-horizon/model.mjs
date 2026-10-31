export function horizon(percent) {
  if (typeof percent !== 'number' || !Number.isFinite(percent) || percent <= 0 || percent >= 100) throw new Error('成功率は0より大きく100より小さい数値で入力してください。');
  return 120 * Math.sqrt((100-percent)/percent);
}
