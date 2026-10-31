import * as T from "./vendor/three.module.min.js";
import {
  createDeck,
  createDummy,
  createHero,
  createPalette,
} from "./actors.mjs";

export function createTrainingScene(
  { host, onFailure, low = false, reducedMotion = false },
) {
  let renderer, observer;
  try {
    let disposed = false, quiet = reducedMotion, lastEvent = 0;
    renderer = new T.WebGLRenderer({
      antialias: !low,
      alpha: true,
      powerPreference: "low-power",
    });
    renderer.setPixelRatio(Math.min(devicePixelRatio || 1, low ? 1 : 1.5));
    renderer.outputColorSpace = T.SRGBColorSpace;
    renderer.toneMapping = T.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.3;
    const scene = new T.Scene();
    scene.fog = new T.Fog(0x183e50, 11, 35);
    const camera = new T.PerspectiveCamera(37, 1, .1, 65);
    camera.position.set(6.4, 4.2, 8.3);
    const palette = createPalette();
    scene.add(new T.HemisphereLight(0xc2efff, 0x4b4b3a, 2.5));
    const sun = new T.DirectionalLight(0xffd3a1, 3.4);
    sun.position.set(-3, 7, 4);
    scene.add(sun);
    const rim = new T.DirectionalLight(0x77dcd4, 2.0);
    rim.position.set(4, 3, -4);
    scene.add(rim);
    const hero = createHero(palette), dummy = createDummy(palette);
    hero.root.position.x = -1.45;
    hero.root.rotation.y = Math.PI / 2;
    dummy.root.position.x = 1.55;
    dummy.root.rotation.y = -Math.PI / 2;
    scene.add(hero.root, dummy.root, createDeck(palette));
    const waterGeometry = new T.PlaneGeometry(80, 80, 26, 26);
    waterGeometry.rotateX(-Math.PI / 2);
    const water = new T.Mesh(
      waterGeometry,
      new T.MeshStandardMaterial({
        color: 0x185568,
        roughness: .68,
        metalness: .2,
        flatShading: true,
      }),
    );
    water.position.y = -.6;
    scene.add(water);
    const positions = waterGeometry.attributes.position,
      base = positions.array.slice();
    for (const x of [-1.45, 1.55]) {
      const shadow = new T.Mesh(
        new T.CircleGeometry(.65, 24),
        new T.MeshBasicMaterial({
          color: 0x071a26,
          transparent: true,
          opacity: .3,
          depthWrite: false,
        }),
      );
      shadow.rotation.x = -Math.PI / 2;
      shadow.scale.y = .6;
      shadow.position.set(x, -.025, 0);
      scene.add(shadow);
    }
    const lantern = new T.Mesh(
      new T.OctahedronGeometry(.18),
      new T.MeshBasicMaterial({ color: 0xffd082 }),
    );
    lantern.position.set(-3.45, .95, 1.3);
    scene.add(lantern);
    const glow = new T.PointLight(0xffbd6b, 8, 5);
    glow.position.copy(lantern.position);
    scene.add(glow);
    const ring = new T.Mesh(
      new T.TorusGeometry(.65, .035, 6, 40),
      new T.MeshBasicMaterial({
        color: 0x96fbe2,
        transparent: true,
        opacity: 0,
        depthWrite: false,
      }),
    );
    ring.rotation.y = Math.PI / 2;
    scene.add(ring);
    const slash = new T.Mesh(
      new T.TorusGeometry(.95, .055, 6, 32, Math.PI * 1.5),
      new T.MeshBasicMaterial({
        color: 0xffda93,
        transparent: true,
        opacity: 0,
        depthWrite: false,
      }),
    );
    scene.add(slash);
    const count = low ? 24 : 64,
      data = new Float32Array(count * 3),
      particleGeometry = new T.BufferGeometry();
    particleGeometry.setAttribute("position", new T.BufferAttribute(data, 3));
    const particles = new T.Points(
      particleGeometry,
      new T.PointsMaterial({
        color: 0xc0ffed,
        size: .055,
        transparent: true,
        opacity: 0,
        depthWrite: false,
      }),
    );
    scene.add(particles);
    const cueTimes = {
      attack: -10000,
      special: -10000,
      hit: -10000,
      guard: -10000,
      hurt: -10000,
      tell: -10000,
      win: -10000,
    };
    const observed = {
      peakTriangles: 0,
      peakDrawCalls: 0,
      dpr: renderer.getPixelRatio(),
      particles: count,
      geometries: 0,
      textures: 0,
    };
    const target = new T.Vector3(0, 1, 0), desired = new T.Vector3();
    host.prepend(renderer.domElement);
    renderer.domElement.setAttribute("aria-hidden", "true");
    const resize = () => {
      if (disposed) return;
      const { width, height } = host.getBoundingClientRect();
      renderer.setSize(Math.max(1, width), Math.max(1, height), false);
      camera.aspect = width / Math.max(1, height);
      camera.updateProjectionMatrix();
    };
    observer = new ResizeObserver(resize);
    observer.observe(host);
    resize();
    const lost = (event) => {
      event.preventDefault();
      if (!disposed) {
        onFailure(
          "描画の接続が切れました。集落の資材や保存は変わっていません。",
        );
      }
    };
    renderer.domElement.addEventListener("webglcontextlost", lost);
    const render = (s, events = [], now = performance.now()) => {
      if (disposed) return;
      for (const e of events) {
        if (e.id <= lastEvent) continue;
        lastEvent = e.id;
        const key = {
          "attack-start": "attack",
          "special-start": "special",
          "target-hit": "hit",
          "guard-start": "guard",
          "guard-success": "guard",
          "player-hit": "hurt",
          "enemy-tell": "tell",
          win: "win",
        }[e.type];
        if (key) cueTimes[key] = now;
      }
      const age = (key) => (now - cueTimes[key]) / 1000;
      const attack = Math.max(0, 1 - age("attack") / .55),
        special = Math.max(0, 1 - age("special") / 1.05),
        hit = Math.max(0, 1 - age("hit") / .3),
        hurt = Math.max(0, 1 - age("hurt") / .35);
      const guard = s.guardUntil > s.time && s.status === "running",
        t = s.time / 1000;
      const breath = quiet ? 0 : Math.sin(t * 2.3) * .018;
      hero.root.position.x = -1.45 +
        (quiet ? 0 : Math.sin(attack * Math.PI) * .55 +
          Math.sin(special * Math.PI) * .7);
      hero.body.position.y = 1.1 + breath;
      hero.body.rotation.z = quiet ? 0 : attack * -.12 + hurt * .17;
      hero.head.rotation.y = quiet ? 0 : Math.sin(t * .7) * .035;
      hero.arms[0].rotation.set(
        guard ? -1.1 : attack * .5,
        0,
        guard ? -.9 : .1,
      );
      hero.arms[1].rotation.set(
        guard ? -1.0 : -(attack * 1.65 + special * 2.1),
        special * -.5,
        guard ? .65 : -.12,
      );
      hero.legs[0].rotation.x = quiet ? 0 : attack * -.35;
      hero.legs[1].rotation.x = quiet ? 0 : attack * .25;
      if (s.status === "won") {
        hero.arms[1].rotation.x = -2.5;
        hero.arms[0].rotation.z = -.4;
      }
      if (s.status === "lost") {
        hero.body.rotation.z = .22;
        hero.head.rotation.x = .2;
      }
      dummy.body.position.y = 1.05 + (quiet ? 0 : Math.sin(t * 1.8) * .035);
      dummy.body.rotation.z = quiet
        ? 0
        : -hit * .3 + (s.telegraphing ? Math.sin(t * 12) * .025 : 0);
      dummy.paddle.rotation.z = s.telegraphing
        ? -1.65
        : age("hurt") < .35
        ? 1.1
        : .2;
      dummy.root.scale.setScalar(s.status === "won" ? .85 : 1);
      ring.position.set(special > 0 ? 1.4 : -1.4, 1.25, 0);
      ring.scale.setScalar(1 + (1 - special) * 1.9);
      ring.material.opacity = quiet ? 0 : special * .7;
      slash.position.set(-.1, 1.45, 0);
      slash.rotation.set(.4, Math.PI / 2, attack * 2.5 + special * 5);
      slash.material.opacity = quiet ? 0 : Math.max(attack, special) * .85;
      const burst = Math.max(special, hit * .7);
      particles.material.opacity = quiet ? 0 : burst;
      if (burst > 0 && !quiet) {
        for (let i = 0; i < count; i++) {
          const a = i * 2.399, spread = (1 - burst) * 2.8 + .1;
          data[i * 3] = 1.4 + Math.cos(a) * spread * (.3 + i / count);
          data[i * 3 + 1] = 1.1 + Math.sin(i * 3.1) * spread * .7;
          data[i * 3 + 2] = Math.sin(a) * spread;
        }
        particleGeometry.attributes.position.needsUpdate = true;
      }
      if (!quiet) {
        for (let i = 0; i < positions.count; i++) {
          positions.setY(
            i,
            base[i * 3 + 1] + Math.sin(base[i * 3] * .3 + t * .65) * .1 +
              Math.cos(base[i * 3 + 2] * .45 + t * .4) * .06,
          );
        }
        positions.needsUpdate = true;
      }
      const narrow = camera.aspect < .85;
      desired.set(narrow ? 7.8 : 6.4, narrow ? 5.4 : 4.2, narrow ? 11.5 : 8.3);
      if (!quiet && special > 0) desired.multiplyScalar(1 - special * .16);
      camera.position.lerp(desired, quiet ? 1 : .16);
      target.set(!quiet && special > 0 ? .35 : 0, 1.0, 0);
      camera.lookAt(target);
      renderer.render(scene, camera);
      observed.peakTriangles = Math.max(
        observed.peakTriangles,
        renderer.info.render.triangles,
      );
      observed.peakDrawCalls = Math.max(
        observed.peakDrawCalls,
        renderer.info.render.calls,
      );
      observed.geometries = renderer.info.memory.geometries;
      observed.textures = renderer.info.memory.textures;
    };
    const dispose = () => {
      if (disposed) return { ...observed, disposed: true };
      disposed = true;
      observer.disconnect();
      renderer.domElement.removeEventListener("webglcontextlost", lost);
      const geometries = new Set(), materials = new Set();
      scene.traverse((o) => {
        if (o.geometry) geometries.add(o.geometry);
        for (const m of Array.isArray(o.material) ? o.material : [o.material]) {
          if (m) materials.add(m);
        }
      });
      geometries.forEach((g) => g.dispose());
      materials.forEach((m) => m.dispose());
      renderer.renderLists.dispose();
      renderer.dispose();
      renderer.forceContextLoss();
      renderer.domElement.remove();
      scene.clear();
      observed.geometries = renderer.info.memory.geometries;
      observed.textures = renderer.info.memory.textures;
      return { ...observed, disposed: true };
    };
    return {
      render,
      resize,
      dispose,
      setReducedMotion(value) {
        quiet = value;
      },
      diagnostics() {
        return { ...observed, disposed };
      },
    };
  } catch (error) {
    observer?.disconnect();
    renderer?.dispose();
    renderer?.forceContextLoss();
    renderer?.domElement.remove();
    throw error;
  }
}
