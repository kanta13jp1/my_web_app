// Original practice paths in a 400 × 400 coordinate system.
export const letters = Object.freeze({
  'く': 'M270 75 L125 200 L270 325',
  'し': 'M135 70 C130 145 118 245 140 294 C162 340 230 318 284 260',
  'つ': 'M75 155 C145 119 270 112 307 155 C360 227 264 287 145 295',
  'へ': 'M65 240 L165 140 Q175 132 185 142 Q252 205 335 246',
  'の': 'M213 113 C210 183 158 274 113 268 C53 260 99 137 170 112 C251 78 311 141 306 216 C304 282 249 313 199 317',
});

// Only nearby, consecutive samples can advance. A jump never fills a gap.
export function advance(points, index, position, radius = 24) {
  if (index >= points.length) return index;
  while (index < points.length && Math.hypot(points[index].x - position.x, points[index].y - position.y) <= radius) index++;
  return index;
}
