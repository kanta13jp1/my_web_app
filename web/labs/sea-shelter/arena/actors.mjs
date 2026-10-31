// Original procedural models. No image planes, purchased meshes or game assets.
import * as T from "./vendor/three.module.js";

// Bake static pieces by material within each articulated joint, keeping draw calls low.
function batch(group) {
  group.updateMatrixWorld(true);
  const bins = new Map();
  for (const child of [...group.children]) {
    if (!child.isMesh) continue;
    const geometry = child.geometry.index
      ? child.geometry.toNonIndexed()
      : child.geometry.clone();
    geometry.applyMatrix4(child.matrix);
    const bin = bins.get(child.material) ?? [];
    bin.push(geometry);
    bins.set(child.material, bin);
    child.geometry.dispose();
    group.remove(child);
  }
  for (const [material, geometries] of bins) {
    const geometry = new T.BufferGeometry();
    for (const key of ["position", "normal", "uv"]) {
      const arrays = geometries.map((g) => g.getAttribute(key));
      if (arrays.some((a) => !a)) continue;
      const data = new Float32Array(
        arrays.reduce((n, a) => n + a.array.length, 0),
      );
      let offset = 0;
      for (const a of arrays) {
        data.set(a.array, offset);
        offset += a.array.length;
      }
      geometry.setAttribute(
        key,
        new T.BufferAttribute(data, arrays[0].itemSize),
      );
    }
    geometries.forEach((g) => g.dispose());
    group.add(new T.Mesh(geometry, material));
  }
  return group;
}
export function createPalette() {
  const colors = {
    skin: 0xd8a679,
    hair: 0x252e36,
    coat: 0x288d8b,
    dark: 0x163f50,
    trim: 0xe8b965,
    scarf: 0xef7645,
    boot: 0x343e44,
    white: 0xf7edcd,
    eye: 0x071c29,
    wood: 0xa17b59,
    pale: 0xd6caa3,
    sea: 0x25616e,
  };
  return Object.fromEntries(
    Object.entries(colors).map((
      [key, color],
    ) => [
      key,
      new T.MeshStandardMaterial({
        color,
        roughness: .86,
        metalness: key === "trim" ? .35 : .03,
      }),
    ]),
  );
}
const sphere = (x, y, z) => new T.SphereGeometry(1, x ?? 12, y ?? 8, z);
function piece(
  group,
  geometry,
  material,
  position,
  scale = [1, 1, 1],
  rotation = [0, 0, 0],
) {
  const mesh = new T.Mesh(geometry, material);
  mesh.position.set(...position);
  mesh.scale.set(...scale);
  mesh.rotation.set(...rotation);
  group.add(mesh);
  return mesh;
}
const ellipsoid = (g, m, p, s) => piece(g, sphere(), m, p, s);
const cylinder = (g, m, p, r, h, rotation = [0, 0, 0]) =>
  piece(
    g,
    new T.CylinderGeometry(r * .86, r, h, 10),
    m,
    p,
    [1, 1, 1],
    rotation,
  );
function joint(parent, x, y, z) {
  const g = new T.Group();
  g.position.set(x, y, z);
  parent.add(g);
  return g;
}

export function createHero(p) {
  const root = new T.Group();
  root.name = "Original lantern keeper";
  const body = joint(root, 0, 1.1, 0);
  ellipsoid(body, p.coat, [0, .4, 0], [.38, .57, .23]);
  ellipsoid(body, p.dark, [0, -.13, 0], [.32, .25, .22]);
  piece(body, new T.BoxGeometry(.65, .095, .48), p.trim, [0, .01, 0]);
  cylinder(body, p.trim, [.22, .24, .23], .08, .04, [Math.PI / 2, 0, 0]);
  for (const x of [-.15, .15]) {
    ellipsoid(body, p.scarf, [x, .8, .13], [.2, .1, .13]);
  }
  ellipsoid(body, p.scarf, [.27, .58, -.12], [.11, .35, .07]);
  for (const x of [-.23, .23]) {
    piece(body, new T.BoxGeometry(.19, .48, .06), p.dark, [x, .23, .22], [
      1,
      1,
      1,
    ], [0, 0, x > 0 ? -.18 : .18]);
  }
  batch(body);
  const head = joint(body, 0, 1.01, 0);
  ellipsoid(head, p.skin, [0, .07, 0], [.255, .31, .235]);
  ellipsoid(head, p.hair, [0, .22, -.06], [.28, .23, .25]);
  for (let i = 0; i < 5; i++) {
    ellipsoid(
      head,
      p.hair,
      [-.23 + i * .105, .29 + Math.sin(i * 2) * .04, .15],
      [.09, .17, .09],
    );
  }
  ellipsoid(head, p.hair, [.03, .05, -.26], [.13, .26, .12]);
  ellipsoid(head, p.skin, [0, .055, .232], [.045, .065, .055]);
  for (const x of [-.105, .105]) {
    ellipsoid(head, p.white, [x, .1, .213], [.063, .045, .035]);
    ellipsoid(head, p.eye, [x, .1, .244], [.026, .03, .013]);
    piece(head, new T.BoxGeometry(.11, .022, .025), p.hair, [x, .172, .22]);
    ellipsoid(head, p.skin, [Math.sign(x) * .26, .04, 0], [.055, .095, .06]);
  }
  piece(head, new T.BoxGeometry(.09, .018, .018), p.scarf, [0, -.065, .223]);
  batch(head);
  const arms = [];
  for (const side of [-1, 1]) {
    const arm = joint(body, side * .41, .64, 0);
    arms.push(arm);
    ellipsoid(arm, p.coat, [side * .02, -.18, 0], [.15, .28, .15]);
    cylinder(arm, p.trim, [0, -.34, 0], .145, .07);
    ellipsoid(arm, p.boot, [0, -.49, .025], [.12, .21, .13]);
    ellipsoid(arm, p.skin, [0, -.7, .04], [.11, .12, .11]);
    if (side === 1) {
      cylinder(arm, p.wood, [0, -.7, .35], .035, 1.05, [Math.PI / 2, 0, 0]);
      piece(
        arm,
        new T.TorusGeometry(.14, .027, 5, 12, Math.PI * 1.4),
        p.trim,
        [0, -.7, .92],
        [1, 1, 1],
        [Math.PI / 2, 0, 0],
      );
      ellipsoid(arm, p.trim, [0, -.7, -.15], [.065, .065, .065]);
    }
    batch(arm);
  }
  const legs = [];
  for (const side of [-1, 1]) {
    const leg = joint(root, side * .18, 1.0, 0);
    legs.push(leg);
    cylinder(leg, p.dark, [0, -.27, 0], .135, .54);
    ellipsoid(leg, p.boot, [0, -.73, .045], [.155, .24, .18]);
    ellipsoid(leg, p.boot, [0, -.9, .12], [.16, .11, .26]);
    cylinder(leg, p.trim, [0, -.57, 0], .153, .055);
    batch(leg);
  }
  return { root, body, head, arms, legs };
}

export function createDummy(p) {
  const root = new T.Group();
  root.name = "Shell buoy training partner";
  const body = joint(root, 0, 1.05, 0);
  ellipsoid(body, p.pale, [0, .15, 0], [.47, .57, .34]);
  cylinder(body, p.scarf, [0, .1, 0], .48, .15);
  cylinder(body, p.wood, [0, -.64, 0], .13, .6);
  piece(body, new T.TorusGeometry(.43, .07, 6, 18), p.sea, [0, -.55, 0], [
    1,
    1,
    1,
  ], [Math.PI / 2, 0, 0]);
  ellipsoid(body, p.white, [0, .83, 0], [.36, .31, .28]);
  for (const x of [-.13, .13]) {
    ellipsoid(body, p.eye, [x, .86, .25], [.05, .06, .02]);
  }
  piece(body, new T.BoxGeometry(.16, .035, .035), p.wood, [0, .72, .26]);
  for (let i = 0; i < 5; i++) {
    piece(
      body,
      new T.BoxGeometry(.055, .29, .04),
      p.trim,
      [-.22 + i * .11, 1.08, 0],
      [1, 1, 1],
      [0, 0, (i - 2) * -.17],
    );
  }
  batch(body);
  const paddle = joint(body, -.5, .4, 0);
  cylinder(paddle, p.wood, [0, -.15, 0], .045, .75);
  ellipsoid(paddle, p.sea, [0, -.54, 0], [.2, .28, .08]);
  batch(paddle);
  return { root, body, paddle };
}

export function createDeck(p) {
  const root = new T.Group();
  for (let i = 0; i < 13; i++) {
    const x = (i - 6) * .55,
      length = 2 * Math.sqrt(Math.max(.5, 3.65 ** 2 - x * x));
    piece(root, new T.BoxGeometry(.52, .2, length), i % 3 ? p.wood : p.pale, [
      x,
      -.14,
      0,
    ]);
  }
  for (const x of [-3.5, 3.5]) {
    for (const z of [-1.3, 1.3]) {
      cylinder(root, p.wood, [x, .34, z], .085, .8);
      ellipsoid(root, p.trim, [x, .79, z], [.11, .1, .11]);
    }
  }
  for (const x of [-3.5, 3.5]) {
    cylinder(root, p.pale, [x, .6, 0], .025, 2.6, [Math.PI / 2, 0, 0]);
  }
  piece(root, new T.TorusGeometry(2.55, .035, 4, 48), p.trim, [0, -.025, 0], [
    1,
    1,
    1,
  ], [Math.PI / 2, 0, 0]);
  batch(root);
  return root;
}
