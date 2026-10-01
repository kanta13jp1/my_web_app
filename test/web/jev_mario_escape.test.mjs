import test from 'node:test';
import assert from 'node:assert/strict';
import {normalizeEscapeSequence, escapeOriginMatches} from '../../web/labs/jev-mario/escape-plan.mjs';

test('escape commands are bounded and defensively copied', () => {
  const input = [{action: 'right_run', frames: 7}, {action: 'right_run_jump', frames: 11},
    {action: 'right_run', frames: 60}];
  const copy = normalizeEscapeSequence(input);
  assert.deepEqual(copy, input);
  input[0].frames = 60;
  assert.equal(copy[0].frames, 7);
  for (const bad of [null, [], [{}], [{action: 'teleport', frames: 1}],
    [{action: 'right_run', frames: 0}], [{action: 'right_run', frames: 1.5}],
    [{action: 'right_run', frames: 61}], Array(4).fill({action: 'right_run', frames: 1}),
    [{action: 'right_run', frames: 60}, {action: 'right_run', frames: 21}]])
    assert.equal(normalizeEscapeSequence(bad), null);
});

test('escape responses reject stale, rewound, damaged, and changed worlds', () => {
  const g = {phase: 'playing', stage: 32, room: 'castle', power: 1, lives: 5,
    frames: 100, p: {x: 500}};
  const origin = {stage: 32, room: 'castle', power: 1, lives: 5, frame: 90, x: 490};
  assert.equal(escapeOriginMatches(g, origin), true);
  for (const change of [{phase: 'dead'}, {stage: 31}, {room: 'overworld'}, {power: 0},
    {lives: 4}, {frames: 89}, {frames: 151}, {p: {x: 539}}])
    assert.equal(escapeOriginMatches({...g, ...change}, origin), false);
  assert.equal(escapeOriginMatches(g, {...origin, x: NaN}), false);
  assert.equal(escapeOriginMatches(g, null), false);
});
