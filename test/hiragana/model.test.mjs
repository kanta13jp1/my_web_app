import { test } from 'node:test';
import assert from 'node:assert/strict';
import { advance } from '../../web/labs/hiragana-garden/model.mjs';
const points = [{x:0,y:0},{x:50,y:0},{x:100,y:0}];
test('jump to end and wrong start cannot complete the guide', () => {
  assert.equal(advance(points, 0, {x:100,y:0}), 0);
  assert.equal(advance(points, 1, {x:0,y:100}), 1);
});
test('consecutive samples can resume and finish without exceeding the end', () => {
  let index = 0;
  for (const point of points) index = advance(points, index, point);
  assert.equal(index, 3);
  assert.equal(advance(points, index, {x:999,y:999}), 3);
});
