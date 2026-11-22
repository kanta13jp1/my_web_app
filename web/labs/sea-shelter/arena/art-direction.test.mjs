import { test } from "node:test";
import assert from "node:assert/strict";
import { artDirection, INK_BANDS } from "./art-direction.mjs";
import { createPalette, createHero, createDummy, createDeck } from "./actors.mjs";
function counts(palette) {
  const roots = [createHero(palette).root, createDummy(palette).root, createDeck(palette)];
  const geometries = new Set();
  let meshes = 0, triangles = 0;
  for (const root of roots) root.traverse((o) => {
    if (!o.isMesh) return;
    meshes++;
    geometries.add(o.geometry);
    triangles += (o.geometry.index?.count ?? o.geometry.attributes.position.count) / 3;
  });
  geometries.forEach((g) => g.dispose());
  return { meshes, triangles };
}
test("ink shares one nearest-filter ramp and preserves the original geometry budget", () => {
  const sea = createPalette(), ink = createPalette({ ink: true });
  assert.deepEqual(Object.keys(ink), Object.keys(sea));
  const ramps = new Set(Object.values(ink).map((m) => m.gradientMap));
  assert.equal(ramps.size, 1);
  const ramp = [...ramps][0];
  assert.deepEqual([...ramp.image.data], [...INK_BANDS]);
  assert.equal(ramp.magFilter, ramp.minFilter);
  assert.equal(ramp.generateMipmaps, false);
  assert(Object.values(ink).every((m) => m.isMeshToonMaterial));
  assert(Object.values(sea).every((m) => m.isMeshStandardMaterial));
  assert.deepEqual(counts(ink), counts(sea));
  Object.values(ink).forEach((m) => m.dispose());
  Object.values(sea).forEach((m) => m.dispose());
  ramp.dispose();
});
test("paper fog has a finite depth range and original art remains the default", () => {
  assert.equal(artDirection().ink, false);
  assert.equal(artDirection().background, null);
  const ink = artDirection(true);
  assert(ink.fogNear > 0 && ink.fogFar > ink.fogNear);
  assert.equal(ink.background, 0xdedacb);
});
