import * as THREE from './vendor/three.module.js';

/** Original procedural educational anatomy; intentionally not a real engine. */
export const STAGES = Object.freeze([
  Object.freeze({ id: 'fan', name: 'ファン', english: 'FAN', number: '01', x: -4.65, color: '#77dce7', description: '大きなファンが空気を取り込む。多くは外側のバイパス流路を通り、一部がエンジンの中心へ進む。', detail: '前面の曲がった翼が回転し、後方の固定翼が流れを整える。バイパス流は、このモデルの青い粒子で表す。' }),
  Object.freeze({ id: 'compressor', name: '圧縮機', english: 'COMPRESSOR', number: '02', x: -2.25, color: '#a3ecef', description: '回転翼と固定翼が交互に並び、中心へ入った空気を段階的に圧縮する。', detail: '後段ほど流路が狭くなる。回転翼は軸とともに回り、その間の固定翼は外側の構造につながっている。' }),
  Object.freeze({ id: 'combustor', name: '燃焼器', english: 'COMBUSTOR', number: '03', x: 0.8, color: '#ff9256', description: '圧縮された空気に燃料を加えて燃焼させ、高温のガスをつくる。', detail: 'オレンジ色は熱のある領域の視覚表現。燃焼は環状のライナー内で続き、外側の空気も冷却や混合に使われる。' }),
  Object.freeze({ id: 'turbine', name: 'タービン', english: 'TURBINE', number: '04', x: 2.95, color: '#ffb378', description: '高温のガスからエネルギーを取り出し、軸を介して圧縮機とファンを回す。', detail: 'タービンが取り出した仕事は同軸のシャフトで前方へ伝わる。翼列の色は材料温度を測った値ではない。' }),
  Object.freeze({ id: 'nozzle', name: 'ノズル', english: 'NOZZLE', number: '05', x: 5.3, color: '#ccd0c7', description: 'ガスを後ろへ導き、速度を高めて排出する。バイパス流とコア流が推進力を生む。', detail: '中心のコーンと周囲の出口が流れを案内する。形状、回転数、推力の表示は学習向けに簡略化した架空のモデル。' }),
]);

const TAU = Math.PI * 2;
const clamp01 = (n, fallback = 0) => Number.isFinite(Number(n)) ? THREE.MathUtils.clamp(Number(n), 0, 1) : fallback;
const mix = THREE.MathUtils.lerp;
const stageOffsets = { fan: -2.7, compressor: -1.05, combustor: 0.4, turbine: 1.65, nozzle: 3.1 };

function profileGeometry(profile, segments = 64, start = 0, arc = TAU) {
  const positions = [], indices = [];
  for (let p = 0; p < profile.length; p += 1) {
    for (let j = 0; j <= segments; j += 1) {
      const theta = start + arc * j / segments;
      positions.push(profile[p][0], Math.cos(theta) * profile[p][1], Math.sin(theta) * profile[p][1]);
      if (p < profile.length - 1 && j < segments) {
        const a = p * (segments + 1) + j;
        const b = a + segments + 1;
        indices.push(a, b, a + 1, b, b + 1, a + 1);
      }
    }
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  return geometry;
}

function shellGeometry(profile, thickness, start, arc, steps) {
  const loop = [...profile, ...profile.map(([x, r]) => [x, r - thickness]).reverse(), profile[0]];
  const geometry = profileGeometry(loop, steps, start, arc);
  // Add radial edge faces so the cut reveals the actual thickness of the casing.
  const positions = Array.from(geometry.attributes.position.array);
  const indices = Array.from(geometry.index.array);
  for (const theta of [start, start + arc]) {
    for (let i = 0; i < profile.length - 1; i += 1) {
      const a = positions.length / 3;
      for (const [x, r] of [profile[i], profile[i + 1], [profile[i + 1][0], profile[i + 1][1] - thickness], [profile[i][0], profile[i][1] - thickness]]) {
        positions.push(x, r * Math.cos(theta), r * Math.sin(theta));
      }
      indices.push(a, a + 1, a + 2, a, a + 2, a + 3);
    }
  }
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  return geometry;
}

/** A closed aerofoil, twisted and swept along its span; one shared mesh per row. */
function bladeGeometry({ root, tip, chord, sweep = 0.24, pitch = 0.42, radialSteps = 7, chordSteps = 4, thickness = 0.023 }) {
  const positions = [], indices = [];
  const stride = chordSteps + 1;
  const layerSize = (radialSteps + 1) * stride;
  for (let side = 0; side < 2; side += 1) {
    for (let i = 0; i <= radialSteps; i += 1) {
      const t = i / radialSteps;
      const radius = mix(root, tip, t);
      const localChord = chord * (0.5 + 0.65 * Math.sin(t * 1.4));
      for (let j = 0; j <= chordSteps; j += 1) {
        const u = j / chordSteps;
        const theta = sweep * t ** 1.65 + (u - 0.5) * localChord / radius;
        const foil = Math.sin(Math.PI * u) * thickness * (1 - t * 0.45);
        const x = (u - 0.5) * pitch * (1.15 - 0.55 * t) + 0.055 * Math.sin(Math.PI * u) + t * t * sweep * 0.4 + (side === 0 ? foil : -foil);
        positions.push(x, Math.cos(theta) * radius, Math.sin(theta) * radius);
        if (i < radialSteps && j < chordSteps) {
          const a = side * layerSize + i * stride + j;
          const b = a + stride;
          if (side === 0) indices.push(a, b, a + 1, b, b + 1, a + 1);
          else indices.push(a, a + 1, b, b, a + 1, b + 1);
        }
      }
    }
  }
  for (let i = 0; i < radialSteps; i += 1) {
    for (const j of [0, chordSteps]) {
      const a = i * stride + j, b = a + stride;
      indices.push(a, a + layerSize, b, b, a + layerSize, b + layerSize);
    }
  }
  for (const i of [0, radialSteps]) {
    for (let j = 0; j < chordSteps; j += 1) {
      const a = i * stride + j;
      indices.push(a, a + 1, a + layerSize, a + 1, a + 1 + layerSize, a + layerSize);
    }
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setIndex(indices);
  geometry.computeVertexNormals();
  return geometry;
}

function seededRandom(seed = 4711) {
  return () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
}

/**
 * @param {{density?: 'low'|'balanced'|'high'}} [options]
 * @returns {{group: THREE.Group, update: Function, stats: object, dispose: Function}}
 */
export function createEngine({ density = 'balanced' } = {}) {
  const detail = density === 'low' ? { ring: 40, fanRadial: 8, fanChord: 4, radial: 4, chord: 3, particles: 1100 } : density === 'high' ? { ring: 88, fanRadial: 14, fanChord: 7, radial: 7, chord: 4, particles: 3500 } : { ring: 64, fanRadial: 10, fanChord: 5, radial: 5, chord: 3, particles: 2200 };
  const group = new THREE.Group();
  group.name = 'ASTRA / AX-01 / Procedural Turbofan';
  group.userData.educational = true;
  const stageGroups = {};
  const rotors = [], cutawayParts = [], emissiveParts = [], stageMaterials = [];
  const registeredGeometries = new Set(), registeredMaterials = new Set();
  let bladeCount = 0, disposed = false;
  const makeMaterial = (parameters, stageId) => {
    const material = new THREE.MeshStandardMaterial({ metalness: 0.78, roughness: 0.3, side: THREE.DoubleSide, ...parameters });
    registeredMaterials.add(material);
    if (stageId) stageMaterials.push({ material, id: stageId, baseEmissive: material.emissive.clone(), baseIntensity: material.emissiveIntensity });
    return material;
  };
  const mat = {
    nacelle: makeMaterial({ color: '#697780', metalness: 0.87, roughness: 0.27 }),
    nacelleDark: makeMaterial({ color: '#273239', metalness: 0.85, roughness: 0.33 }),
    black: makeMaterial({ color: '#111a20', metalness: 0.6, roughness: 0.38 }),
    fastener: makeMaterial({ color: '#87979b', metalness: 0.91, roughness: 0.23 }),
    copper: makeMaterial({ color: '#ab7549', metalness: 0.85, roughness: 0.3 }),
    shaft: makeMaterial({ color: '#a7b6b9', metalness: 0.94, roughness: 0.18 }),
  };
  const metals = {};
  for (const stage of STAGES) {
    const stageGroup = new THREE.Group();
    stageGroup.name = stage.english;
    stageGroup.userData.stageId = stage.id;
    stageGroup.userData.anchor = new THREE.Vector3(stage.x, 0, 0);
    group.add(stageGroup);
    stageGroups[stage.id] = stageGroup;
    metals[stage.id] = {
      light: makeMaterial({ color: stage.id === 'turbine' ? '#a99c89' : '#aebfc4', roughness: 0.25 }, stage.id),
      dark: makeMaterial({ color: '#36444d', roughness: 0.33 }, stage.id),
      accent: makeMaterial({ color: stage.color, emissive: stage.color, emissiveIntensity: 0.32, metalness: 0.5 }, stage.id),
    };
  }
  function mesh(geometry, material, parent, name, stageId) {
    registeredGeometries.add(geometry);
    const object = new THREE.Mesh(geometry, material);
    object.name = name;
    object.castShadow = false;
    object.receiveShadow = false;
    object.userData.stageId = stageId || parent.userData.stageId;
    parent.add(object);
    return object;
  }
  function ring(parent, x, radius, width, depth, material, name = 'Machined collar') {
    return mesh(profileGeometry([[x - width / 2, radius - depth], [x - width / 2, radius], [x + width / 2, radius], [x + width / 2, radius - depth], [x - width / 2, radius - depth]], detail.ring), material, parent, name);
  }
  function shaft(parent, from, to, radius, material = mat.shaft) {
    return mesh(profileGeometry([[from, 0], [from, radius], [to, radius], [to, 0]], 32), material, parent, 'Concentric drive shaft');
  }
  function instanced(geometry, material, count, parent, name, matrixAt) {
    registeredGeometries.add(geometry);
    const object = new THREE.InstancedMesh(geometry, material, count);
    const matrix = new THREE.Matrix4();
    for (let i = 0; i < count; i += 1) object.setMatrixAt(i, matrixAt(i, matrix));
    object.instanceMatrix.needsUpdate = true;
    object.name = name;
    object.userData.stageId = parent.userData.stageId;
    parent.add(object);
    return object;
  }
  function blades(parent, { x, root, tip, count, chord, pitch, sweep, speed = 0, fan = false, material }) {
    const assembly = new THREE.Group();
    assembly.name = speed ? 'Rotating aerofoil row' : 'Stationary guide vane row';
    assembly.position.x = x;
    assembly.userData.stageId = parent.userData.stageId;
    parent.add(assembly);
    const geometry = bladeGeometry({ root, tip, chord, pitch, sweep, radialSteps: fan ? detail.fanRadial : detail.radial, chordSteps: fan ? detail.fanChord : detail.chord, thickness: fan ? 0.027 : 0.013 });
    const object = instanced(geometry, material, count, assembly, `${count} ${speed ? 'rotor blades' : 'stator vanes'}`, (i, matrix) => matrix.makeRotationX(TAU * i / count));
    bladeCount += count;
    if (speed) rotors.push({ group: assembly, speed, direction: speed > 0 ? 1 : -1 });
    return { group: assembly, blades: object };
  }
  function bolts(parent, x, radius, count = 28) {
    const geometry = new THREE.CylinderGeometry(0.035, 0.035, 0.045, 6, 1);
    geometry.rotateZ(Math.PI / 2);
    return instanced(geometry, mat.fastener, count, parent, 'Hexagonal fasteners', (i, matrix) => {
      const angle = i / count * TAU;
      return matrix.makeTranslation(x, radius * Math.cos(angle), radius * Math.sin(angle));
    });
  }
  function casing(parent, profile, thickness, material, { sectors = 12, name = 'Split core casing', opening = true } = {}) {
    for (let i = 0; i < sectors; i += 1) {
      const start = i / sectors * TAU;
      const mid = start + Math.PI / sectors;
      // The visible quarter/half faces +Y and +Z: a generous cutaway window.
      const removable = opening && (Math.sin(mid) > -0.14 || Math.cos(mid) > 0.83);
      const panelMaterial = removable ? material.clone() : material;
      if (removable) {
        panelMaterial.transparent = true;
        panelMaterial.depthWrite = false;
        panelMaterial.forceSinglePass = true;
        registeredMaterials.add(panelMaterial);
      }
      const panel = mesh(shellGeometry(profile, thickness, start + 0.005, TAU / sectors - 0.01, Math.max(3, Math.round(detail.ring / sectors))), panelMaterial, parent, `${name} ${i + 1}`);
      if (removable) cutawayParts.push({ mesh: panel, material: panelMaterial, y: Math.cos(mid), z: Math.sin(mid), outer: name.includes('Nacelle') });
    }
  }
  function pipe(parent, points, radius = 0.028, material = mat.copper) {
    const curve = new THREE.CatmullRomCurve3(points.map(p => new THREE.Vector3(...p)));
    return mesh(new THREE.TubeGeometry(curve, 28, radius, 6, false), material, parent, 'Formed external line');
  }

  // FRONT: 26 broad scimitar fan blades behind a turned spinner and intake lip.
  const fan = stageGroups.fan;
  blades(fan, { x: -4.73, root: 0.51, tip: 2.38, count: 26, chord: 0.52, pitch: 0.62, sweep: -0.31, speed: 8.3, fan: true, material: metals.fan.light });
  const spinner = mesh(profileGeometry([[-5.72, 0.015], [-5.65, 0.13], [-5.47, 0.3], [-5.17, 0.46], [-4.74, 0.55], [-4.33, 0.51]], detail.ring), mat.shaft, fan, 'Ogive fan spinner');
  // A bright asymmetrical spinner seam makes real rotation legible even at idle.
  const spinnerMarkGeometry = new THREE.TubeGeometry(new THREE.CatmullRomCurve3(Array.from({ length: 25 }, (_, i) => {
    const t = i / 24, radius = mix(0.09, 0.48, t);
    return new THREE.Vector3(mix(-5.67, -5.08, t), radius * Math.cos(t * 5.5), radius * Math.sin(t * 5.5));
  })), 32, 0.012, 5, false);
  mesh(spinnerMarkGeometry, metals.fan.accent, spinner, 'Spinner motion witness');
  rotors.push({ group: spinner, speed: 8.3 });
  ring(fan, -4.71, 0.61, 0.15, 0.13, metals.fan.dark, 'Fan root retaining disk');
  bolts(fan, -4.88, 0.56, 20);
  blades(fan, { x: -3.92, root: 1.33, tip: 2.39, count: 16, chord: 0.25, pitch: -0.23, sweep: 0.1, material: metals.fan.dark });
  ring(fan, -5.29, 2.49, 0.16, 0.045, metals.fan.light, 'Polished inlet lip');
  ring(fan, -5.18, 2.5, 0.036, 0.025, metals.fan.accent, 'Intake witness ring');
  ring(fan, -4.74, 2.45, 0.095, 0.05, metals.fan.dark, 'Fan containment band');
  shaft(fan, -4.74, -3.67, 0.24);
  casing(fan, [[-5.43, 2.45], [-5.29, 2.57], [-4.32, 2.69], [-3.58, 2.71]], 0.07, mat.nacelle, { name: 'Nacelle intake panel', sectors: 16 });

  // COMPRESSION: six shrinking blade rows, with fixed rows between them.
  const compressor = stageGroups.compressor;
  mesh(profileGeometry([[-3.92, 0.29], [-3.7, 0.62], [-3.42, 0.7], [-2.8, 0.75], [-1.9, 0.79], [-0.69, 0.82], [-0.52, 0.82]], detail.ring), metals.compressor.dark, compressor, 'Compressor drum');
  for (let i = 0; i < 6; i += 1) {
    const x = -3.48 + i * 0.48;
    const root = 0.67 + i * 0.028;
    const tip = 1.55 - i * 0.075;
    blades(compressor, { x, root, tip, count: 32 + i * 2, chord: 0.19 - i * 0.008, pitch: 0.22, sweep: 0.08, speed: 16.8, material: metals.compressor.light });
    blades(compressor, { x: x + 0.235, root: root + 0.01, tip: tip - 0.025, count: 30 + i * 2, chord: 0.14, pitch: -0.19, sweep: -0.07, material: metals.compressor.dark });
    ring(compressor, x, root + 0.06, 0.115, 0.1, mat.shaft, 'Compressor rotor disk');
    ring(compressor, x + 0.23, tip + 0.018, 0.055, 0.035, i % 2 ? metals.compressor.dark : metals.compressor.light, 'Stator root ring');
  }
  casing(compressor, [[-3.7, 1.68], [-2.85, 1.57], [-1.82, 1.41], [-0.42, 1.25]], 0.042, metals.compressor.dark);
  casing(compressor, [[-3.55, 2.71], [-2.28, 2.7], [-0.47, 2.62]], 0.07, mat.nacelle, { name: 'Nacelle bypass panel', sectors: 16 });
  for (const [x, r] of [[-3.59, 1.68], [-1.83, 1.44], [-0.43, 1.26]]) {
    ring(compressor, x, r, 0.09, 0.06, metals.compressor.light);
    bolts(compressor, x - 0.05, r - 0.027, 28);
  }
  shaft(compressor, -3.68, -0.43, 0.215);
  for (const theta of [Math.PI * 1.14, Math.PI * 1.45]) {
    const r = 1.74;
    pipe(compressor, [[-3.51, r * Math.cos(theta), r * Math.sin(theta)], [-2.8, r * Math.cos(theta), r * Math.sin(theta)], [-1.8, (r - 0.14) * Math.cos(theta), (r - 0.14) * Math.sin(theta)], [-0.5, (r - 0.35) * Math.cos(theta), (r - 0.35) * Math.sin(theta)]], 0.025, mat.fastener);
  }

  // HOT SECTION: annular liner, repeated injector throats and visible flame cups.
  const combustor = stageGroups.combustor;
  const flameMaterial = makeMaterial({ color: '#ff7835', emissive: '#ff550f', emissiveIntensity: 2.1, metalness: 0.08, roughness: 0.5 }, 'combustor');
  const linerMaterial = makeMaterial({ color: '#6c4330', emissive: '#d84d1f', emissiveIntensity: 0.22, metalness: 0.7 }, 'combustor');
  emissiveParts.push({ material: flameMaterial, base: 2.1 });
  emissiveParts.push({ material: linerMaterial, base: 0.25 });
  casing(combustor, [[-0.35, 1.26], [0.03, 1.36], [1.5, 1.4], [1.88, 1.33]], 0.047, metals.combustor.dark, { name: 'Combustion chamber outer casing' });
  casing(combustor, [[-0.15, 1.12], [0.33, 1.16], [1.42, 1.17], [1.79, 1.11]], 0.035, linerMaterial, { name: 'Perforated annular flame liner', sectors: 16 });
  mesh(profileGeometry([[-0.25, 0.58], [-0.1, 0.62], [1.54, 0.67], [1.88, 0.64]], 48), metals.combustor.dark, combustor, 'Inner combustion liner');
  ring(combustor, -0.17, 1.12, 0.18, 0.37, metals.combustor.dark, 'Annular combustor dome');
  ring(combustor, 0.05, 1.37, 0.07, 0.04, mat.copper, 'Fuel distribution manifold');
  ring(combustor, 1.68, 1.22, 0.055, 0.028, metals.combustor.accent, 'Combustor exit lip');
  const cup = profileGeometry([[-0.16, 0.075], [-0.07, 0.12], [0.08, 0.12], [0.15, 0.105], [0.15, 0.076], [-0.16, 0.045]], 12);
  instanced(cup, mat.copper, 16, combustor, 'Sixteen fuel injector cups', (i, matrix) => {
    const theta = i / 16 * TAU;
    return matrix.makeTranslation(0, 0.88 * Math.cos(theta), 0.88 * Math.sin(theta));
  });
  const flameGeo = profileGeometry([[0.07, 0.015], [0.16, 0.067], [0.4, 0.09], [0.8, 0.048], [1.3, 0.008]], 9);
  const flames = instanced(flameGeo, flameMaterial, 16, combustor, 'Stylized continuous flame tongues', (i, matrix) => {
    const theta = i / 16 * TAU;
    return matrix.makeTranslation(0, 0.88 * Math.cos(theta), 0.88 * Math.sin(theta));
  });
  for (const x of [0.39, 0.72, 1.05, 1.38]) {
    const geometry = new THREE.TorusGeometry(0.042, 0.009, 4, 6);
    geometry.rotateY(Math.PI / 2);
    instanced(geometry, mat.black, 24, combustor, 'Liner cooling perforation rims', (i, matrix) => {
      const theta = i / 24 * TAU;
      const orientation = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(1, 0, 0), new THREE.Vector3(0, Math.cos(theta), Math.sin(theta)));
      return matrix.compose(new THREE.Vector3(x, 1.177 * Math.cos(theta), 1.177 * Math.sin(theta)), orientation, new THREE.Vector3(1, 1, 1));
    });
  }
  for (const theta of [3.55, 4.05, 4.55, 5.05]) {
    const radial = r => [r * Math.cos(theta), r * Math.sin(theta)];
    const a = radial(1.44), b = radial(1.62), c = radial(1.51);
    pipe(combustor, [[0.02, ...a], [0.25, ...b], [0.75, ...b], [1.34, ...c]], 0.036, mat.copper);
  }
  ring(combustor, -0.33, 1.29, 0.1, 0.05, metals.combustor.light);
  ring(combustor, 1.87, 1.34, 0.12, 0.055, metals.combustor.light);
  bolts(combustor, -0.39, 1.25, 32);
  bolts(combustor, 1.94, 1.3, 32);
  shaft(combustor, -0.42, 1.99, 0.21);
  casing(combustor, [[-0.4, 2.61], [0.75, 2.53], [1.96, 2.39]], 0.065, mat.nacelle, { name: 'Nacelle hot-section panel', sectors: 16 });

  // TURBINE: fixed nozzle guide vanes alternate with three driven rotor rows.
  const turbine = stageGroups.turbine;
  mesh(profileGeometry([[2.0, 0.67], [2.7, 0.65], [3.63, 0.55], [4.05, 0.43]], 48), metals.turbine.dark, turbine, 'Turbine disk drum');
  for (let i = 0; i < 3; i += 1) {
    const x = 2.22 + i * 0.61, root = 0.67 - i * 0.035, tip = 1.23 - i * 0.046;
    blades(turbine, { x: x - 0.17, root, tip, count: 30 + i * 4, chord: 0.15, pitch: -0.2, sweep: -0.07, material: metals.turbine.dark });
    blades(turbine, { x: x + 0.09, root, tip: tip - 0.025, count: 36 + i * 4, chord: 0.15, pitch: 0.25, sweep: 0.04, speed: i === 0 ? 19 : 11.4, material: metals.turbine.light });
    ring(turbine, x + 0.09, root + 0.05, 0.11, 0.15, metals.turbine.light, 'Turbine rotor disk');
    ring(turbine, x - 0.17, tip + 0.025, 0.06, 0.035, i === 0 ? metals.turbine.accent : metals.turbine.dark, 'Turbine vane retaining ring');
  }
  casing(turbine, [[2.03, 1.32], [2.74, 1.27], [3.43, 1.22], [3.95, 1.13]], 0.04, metals.turbine.dark);
  ring(turbine, 2.04, 1.35, 0.09, 0.055, metals.turbine.light);
  ring(turbine, 3.93, 1.16, 0.09, 0.055, metals.turbine.light);
  bolts(turbine, 2, 1.31, 28);
  shaft(turbine, 1.98, 4.04, 0.19);
  casing(turbine, [[2.02, 2.38], [3.04, 2.2], [4.02, 1.99]], 0.06, mat.nacelle, { name: 'Nacelle exhaust-transition panel', sectors: 16 });

  // EXHAUST: exhaust struts, centerbody, faceted nozzle petals, and a bypass lip.
  const nozzle = stageGroups.nozzle;
  mesh(profileGeometry([[4.0, 0.43], [4.34, 0.46], [4.86, 0.36], [5.46, 0.2], [6.11, 0.012]], detail.ring), metals.nozzle.light, nozzle, 'Long exhaust centerbody');
  blades(nozzle, { x: 4.23, root: 0.43, tip: 1.12, count: 9, chord: 0.095, pitch: 0.18, sweep: 0, material: metals.nozzle.dark });
  casing(nozzle, [[4.07, 1.13], [4.66, 1.08], [5.31, 0.98], [5.71, 0.88]], 0.04, metals.nozzle.light, { sectors: 18, name: 'Core nozzle petal' });
  ring(nozzle, 4.08, 1.15, 0.12, 0.06, metals.nozzle.dark);
  ring(nozzle, 5.73, 0.885, 0.035, 0.033, mat.fastener, 'Core exit edge');
  casing(nozzle, [[4.06, 1.97], [4.51, 1.84], [5.08, 1.69]], 0.055, mat.nacelle, { name: 'Nacelle bypass exit panel', sectors: 16 });
  ring(nozzle, 5.07, 1.71, 0.055, 0.04, metals.nozzle.light, 'Bypass exhaust lip');
  bolts(nozzle, 4.02, 1.1, 24);

  // Delicate dark retention hoops tie the continuous outer body together.
  for (const [id, x, radius] of [['fan', -3.61, 2.72], ['compressor', -0.44, 2.635], ['combustor', 1.99, 2.405], ['turbine', 4.04, 2.005]]) {
    casing(stageGroups[id], [[x - 0.03, radius], [x + 0.03, radius]], 0.045, mat.nacelleDark, { sectors: 8, name: 'Nacelle structural hoop' });
  }

  // Continuous air paths use a single GPU point cloud, with deterministic seeds.
  const count = detail.particles;
  const pointPositions = new Float32Array(count * 3);
  const pointColors = new Float32Array(count * 3);
  const random = seededRandom();
  const particles = Array.from({ length: count }, (_, i) => ({
    phase: random(), angle: random() * TAU, radial: random(), speed: 0.83 + random() * 0.34, bypass: i % 10 < 7,
  }));
  const pointGeometry = new THREE.BufferGeometry();
  pointGeometry.setAttribute('position', new THREE.BufferAttribute(pointPositions, 3).setUsage(THREE.DynamicDrawUsage));
  pointGeometry.setAttribute('color', new THREE.BufferAttribute(pointColors, 3).setUsage(THREE.DynamicDrawUsage));
  registeredGeometries.add(pointGeometry);
  const pointMaterial = new THREE.ShaderMaterial({
    uniforms: { opacity: { value: 0.72 } },
    vertexColors: true,
    transparent: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
    vertexShader: 'varying vec3 vColor; void main(){ vColor=color; vec4 mv=modelViewMatrix*vec4(position,1.0); gl_Position=projectionMatrix*mv; gl_PointSize=clamp(43.0/max(1.0,-mv.z),1.2,4.5); }',
    fragmentShader: 'uniform float opacity; varying vec3 vColor; void main(){ float r=length(gl_PointCoord-0.5)*2.0; if(r>1.0) discard; float a=pow(1.0-r,1.6); gl_FragColor=vec4(vColor,opacity*a); }',
  });
  registeredMaterials.add(pointMaterial);
  const flowPoints = new THREE.Points(pointGeometry, pointMaterial);
  flowPoints.name = 'Cyan bypass / orange hot-core flow';
  flowPoints.frustumCulled = false;
  flowPoints.userData.ignorePick = true;
  group.add(flowPoints);

  const stats = {
    density,
    triangles: 0,
    drawCalls: 0,
    instancedBlades: bladeCount,
    flowParticles: count,
    stageCount: STAGES.length,
    nominalLength: 11.83,
    nominalDiameter: 5.44,
    units: 'arbitrary educational model units',
    provenance: 'Original procedural geometry · GPT-6 Astra · xhigh',
  };
  group.traverse(object => {
    if (object.isMesh) {
      stats.drawCalls += 1;
      stats.triangles += (object.geometry.index ? object.geometry.index.count : object.geometry.attributes.position.count) / 3 * (object.isInstancedMesh ? object.count : 1);
    } else if (object.isPoints) stats.drawCalls += 1;
  });
  Object.freeze(stats);
  group.userData.stats = stats;
  const state = { throttle: 0.62, explode: 0, cutaway: 1, flow: 1, spool: 0.62 };
  let elapsed = 0, previousSelected = null;

  function update(dt = 0, input = {}) {
    if (disposed) return;
    const delta = Number.isFinite(dt) ? THREE.MathUtils.clamp(dt, 0, 0.1) : 0;
    const damping = delta === 0 ? 1 : 1 - Math.exp(-delta * 5.5);
    elapsed += delta;
    state.throttle = mix(state.throttle, clamp01(input.throttle ?? state.throttle, state.throttle), damping);
    state.explode = mix(state.explode, clamp01(input.explode ?? state.explode), damping);
    state.cutaway = mix(state.cutaway, clamp01(input.cutaway ?? state.cutaway), damping);
    state.flow = mix(state.flow, clamp01(input.flow ?? state.flow), damping);
    state.spool = mix(state.spool, input.running === false ? 0 : 0.13 + state.throttle * 0.87, 1 - Math.exp(-Math.max(delta, 0.001) * 2.8));
    for (const stage of STAGES) stageGroups[stage.id].position.x = stageOffsets[stage.id] * state.explode;
    for (const rotor of rotors) rotor.group.rotation.x = (rotor.group.rotation.x + delta * rotor.speed * state.spool) % TAU;
    for (const part of cutawayParts) {
      const opening = state.cutaway;
      part.material.opacity = 1 - opening;
      part.mesh.visible = opening < 0.998;
      part.mesh.position.y = part.y * opening * (part.outer ? 0.24 : 0.11);
      part.mesh.position.z = part.z * opening * (part.outer ? 0.24 : 0.11);
    }
    const selected = STAGES.some(stage => stage.id === input.selected) ? input.selected : null;
    if (selected !== previousSelected) {
      for (const part of stageMaterials) {
        part.material.emissive.copy(part.baseEmissive);
        part.material.emissiveIntensity = part.baseIntensity;
        if (part.id === selected) {
          part.material.emissive.lerp(new THREE.Color(STAGES.find(stage => stage.id === selected).color), 0.5);
          part.material.emissiveIntensity = Math.max(0.25, part.baseIntensity + 0.22);
        }
      }
      previousSelected = selected;
    }
    for (const part of emissiveParts) part.material.emissiveIntensity = part.base * (0.18 + state.spool * 0.93) * (1 + Math.sin(elapsed * 8) * 0.027);
    flames.visible = state.spool > 0.025;
    flowPoints.visible = state.flow > 0.005;
    pointMaterial.uniforms.opacity.value = state.flow * (0.3 + state.spool * 0.5);
    if (flowPoints.visible) {
      for (let i = 0; i < count; i += 1) {
        const p = particles[i];
        p.phase = (p.phase + delta * (0.025 + state.spool * 0.16) * p.speed * (input.running === false ? state.spool : 1)) % 1;
        const x = mix(-6.7, 7.5, p.phase);
        let radius, temperature = 0;
        if (p.bypass) {
          const base = x < -4.3 ? 2.03 : x < 2 ? 2.02 - (x + 4.3) * 0.035 : 1.8 - Math.max(0, x - 2) * 0.11;
          radius = base + (p.radial - 0.5) * 0.38;
        } else {
          const base = x < -4.2 ? 0.45 + (x + 6.7) * 0.16 : x < -0.3 ? 1.18 - (x + 4.2) * 0.074 : x < 3.9 ? 0.9 : 0.91 - (x - 3.9) * 0.12;
          radius = Math.max(0.12, base + (p.radial - 0.5) * 0.25);
          temperature = THREE.MathUtils.smoothstep(x, -0.15, 1.35) * (1 - THREE.MathUtils.smoothstep(x, 5.5, 8) * 0.38);
        }
        const angle = p.angle + x * (p.bypass ? 0.08 : 0.25) + (p.bypass ? 0.02 : 0.04) * Math.sin(elapsed + p.phase * TAU);
        // Interpolate stage offsets along the airway, preserving a continuous
        // stream through the spaces opened by the exploded view.
        const expansionOffset = x < -4.65 ? stageOffsets.fan : x < -2.25 ? mix(stageOffsets.fan, stageOffsets.compressor, (x + 4.65) / 2.4) : x < 0.8 ? mix(stageOffsets.compressor, stageOffsets.combustor, (x + 2.25) / 3.05) : x < 2.95 ? mix(stageOffsets.combustor, stageOffsets.turbine, (x - 0.8) / 2.15) : x < 5.3 ? mix(stageOffsets.turbine, stageOffsets.nozzle, (x - 2.95) / 2.35) : stageOffsets.nozzle;
        const at = i * 3;
        pointPositions[at] = x + expansionOffset * state.explode;
        pointPositions[at + 1] = Math.cos(angle) * radius;
        pointPositions[at + 2] = Math.sin(angle) * radius;
        pointColors[at] = mix(0.18, 1.0, temperature);
        pointColors[at + 1] = mix(0.71, 0.25, temperature);
        pointColors[at + 2] = mix(0.88, 0.025, temperature);
      }
      pointGeometry.attributes.position.needsUpdate = true;
      pointGeometry.attributes.color.needsUpdate = true;
    }
    group.userData.currentState = { ...state, selected };
  }

  function dispose() {
    if (disposed) return;
    disposed = true;
    for (const geometry of registeredGeometries) geometry.dispose();
    for (const material of registeredMaterials) material.dispose();
    group.removeFromParent();
    group.clear();
  }
  update(0, {});
  return { group, update, stats, dispose };
}
