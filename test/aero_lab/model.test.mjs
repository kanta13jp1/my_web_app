import test from 'node:test';
import assert from 'node:assert/strict';
import { createEngine, STAGES } from '../../web/labs/aero-lab/aero-engine.js';
import { deriveMetrics } from '../../web/labs/aero-lab/simulation.js';

test('all density modes have finite geometry across interaction states', () => {
  assert.equal(STAGES.length, 5);
  for (const density of ['low', 'balanced', 'high']) {
    const engine = createEngine({ density });
    for (const state of [
      { throttle: 0, explode: 0, cutaway: false, flow: false, running: false },
      { throttle: 1, explode: 1, cutaway: true, flow: true, running: true },
    ]) {
      engine.update(0.016, state); engine.group.updateMatrixWorld(true);
      engine.group.traverse((object) => {
        assert.ok(object.matrixWorld.elements.every(Number.isFinite));
        for (const attribute of Object.values(object.geometry?.attributes ?? {})) {
          assert.ok(attribute.array.every(Number.isFinite));
        }
      });
    }
    assert.ok(engine.stats.drawCalls < 300);
    engine.dispose(); engine.dispose();
  }
});

test('fault reduces relative thrust and raises heat, without operational units', () => {
  for (const throttle of [0, 0.35, 0.6, 1]) {
    const normal = deriveMetrics({ throttle });
    const fault = deriveMetrics({ throttle, fault: true });
    assert.ok(fault.thrustPercent <= normal.thrustPercent);
    assert.ok(fault.temperatureIndex > normal.temperatureIndex);
    assert.ok(fault.temperatureIndex <= 100);
  }
});
