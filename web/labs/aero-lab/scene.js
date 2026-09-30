import * as THREE from './vendor/three.module.js';
import { OrbitControls } from './vendor/OrbitControls.js';
import { RoomEnvironment } from './vendor/RoomEnvironment.js';
import { createEngine } from './aero-engine.js';

// Owns every GPU allocation. No user data, parent-window bridge or API calls.
export function createScene(host, state) {
  const disposeStack = [];
  let disposed = false, frame = 0;
  const dispose = () => {
    if (disposed) return;
    disposed = true;
    cancelAnimationFrame(frame);
    for (const clean of disposeStack.reverse()) { try { clean(); } catch { /* release remaining resources */ } }
  };
  try {
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
    disposeStack.push(() => { renderer.dispose(); renderer.forceContextLoss(); renderer.domElement.remove(); });
    renderer.setPixelRatio(Math.min(devicePixelRatio, 1.5));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 0.95;
    host.append(renderer.domElement);
    renderer.domElement.setAttribute('aria-label', '3Dターボファン。ドラッグで回転、スクロールで拡大。');
    const scene = new THREE.Scene();
    const room = new RoomEnvironment();
    const pmrem = new THREE.PMREMGenerator(renderer);
    let env;
    try { env = pmrem.fromScene(room, 0.04); } finally { room.dispose(); pmrem.dispose(); }
    disposeStack.push(() => env.dispose());
    scene.environment = env.texture; scene.environmentIntensity = 0.75;
    const camera = new THREE.PerspectiveCamera(32, 1, 0.1, 120);
    camera.position.set(-8, 5, 15);
    const controls = new OrbitControls(camera, renderer.domElement);
    disposeStack.push(() => controls.dispose());
    controls.enableDamping = true; controls.dampingFactor = 0.07;
    controls.minDistance = 8; controls.maxDistance = 32; controls.maxPolarAngle = Math.PI * 0.85;
    for (const [color, intensity, position] of [[0xd9edff, 4, [-3, 9, 7]], [0x6ecddd, 3, [3, 3, -8]], [0xffb483, 2, [8, 1, 3]]]) {
      const light = new THREE.DirectionalLight(color, intensity); light.position.fromArray(position); scene.add(light);
    }
    scene.add(new THREE.AmbientLight(0xbdd9ee, 0.7));
    const engine = createEngine({ density: host.clientWidth < 600 ? 'low' : 'balanced' });
    disposeStack.push(() => engine.dispose()); scene.add(engine.group);
    const grid = new THREE.GridHelper(40, 40, 0x294453, 0x172833);
    grid.position.y = -3.15; scene.add(grid);
    disposeStack.push(() => { grid.geometry.dispose(); grid.material.dispose(); });
    const target = camera.position.clone();
    let moving = false;
    controls.addEventListener('start', () => { moving = false; });
    const resize = () => {
      const width = Math.max(1, host.clientWidth), height = Math.max(1, host.clientHeight);
      renderer.setSize(width, height); camera.aspect = width / height; camera.updateProjectionMatrix();
    };
    const observer = new ResizeObserver(resize); observer.observe(host); resize();
    disposeStack.push(() => observer.disconnect());
    let previous = performance.now();
    function tick(now) {
      if (disposed) return;
      const dt = Math.min((now - previous) / 1000, 0.05); previous = now;
      engine.update(dt, state);
      if (moving) {
        camera.position.lerp(target, 1 - Math.exp(-dt * 3));
        controls.target.lerp(new THREE.Vector3(), 1 - Math.exp(-dt * 3));
        if (camera.position.distanceTo(target) < 0.01) moving = false;
      }
      controls.update(); renderer.render(scene, camera);
      frame = requestAnimationFrame(tick);
    }
    const visibility = () => {
      cancelAnimationFrame(frame);
      if (!document.hidden && !disposed) { previous = performance.now(); frame = requestAnimationFrame(tick); }
    };
    document.addEventListener('visibilitychange', visibility);
    disposeStack.push(() => document.removeEventListener('visibilitychange', visibility));
    const lost = (event) => {
      event.preventDefault(); dispose();
      const status = document.createElement('p'); status.className = 'scene-error'; status.setAttribute('role', 'alert');
      status.textContent = '3D表示が停止しました。再読み込みすると再開できます。'; host.append(status);
    };
    renderer.domElement.addEventListener('webglcontextlost', lost);
    disposeStack.push(() => renderer.domElement.removeEventListener('webglcontextlost', lost));
    visibility();
    return { dispose, view(name) {
      target.fromArray(({ overview: [-8, 5, 15], front: [-18, 2, 3], side: [0, 4, 23] })[name] ?? [-8, 5, 15]); moving = true;
    } };
  } catch (error) { dispose(); throw error; }
}
