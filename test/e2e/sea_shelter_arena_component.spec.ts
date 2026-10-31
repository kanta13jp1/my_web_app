import { expect, test } from "@playwright/test";
test.use({ launchOptions: { args: ["--enable-unsafe-swiftshader"] } });
test.setTimeout(180000);
test(
  "twenty real 3D lifecycles release GPU geometry, canvases, observers and global listeners",
  async ({ page }, info) => {
    await page.goto("/labs/sea-shelter/arena/index.html");
    const cdp = await page.context().newCDPSession(page);
    const ids: string[] = [];
    for (const expression of ["window", "document"]) {
      ids.push(
        (await cdp.send("Runtime.evaluate", {
          expression,
          objectGroup: "arena-lifecycle",
        })).result.objectId!,
      );
    }
    const counts = () =>
      Promise.all(
        ids.map(async (objectId) =>
          (await cdp.send("DOMDebugger.getEventListeners", { objectId }))
            .listeners.length
        ),
      );
    const before = await counts();
    const results = await page.evaluate(async () => {
      const moduleUrl = "/labs/sea-shelter/arena/scene.mjs",
        modelUrl = "/labs/sea-shelter/arena/model.mjs";
      const { createTrainingScene } = await import(moduleUrl);
      const { newTraining, trainingCommand } = await import(modelUrl);
      const native = globalThis.ResizeObserver;
      const active = new Set<ResizeObserver>();
      globalThis.ResizeObserver = class extends native {
        constructor(callback: ResizeObserverCallback) {
          super(callback);
          active.add(this);
        }
        disconnect() {
          active.delete(this);
          super.disconnect();
        }
      };
      const results = [];
      try {
        for (let i = 0; i < 20; i++) {
          const host = document.createElement("div");
          host.style.cssText = "width:375px;height:350px;position:relative";
          document.body.append(host);
          const scene = createTrainingScene({
            host,
            low: true,
            onFailure: () => {
              throw Error("Unexpected context loss");
            },
          });
          scene.render(newTraining(), [], 0);
          const action = trainingCommand(
            { ...newTraining(), charge: 100 },
            "special",
          );
          scene.render(action.state, action.events, 100);
          scene.render(action.state, [], 250);
          const peak = scene.diagnostics();
          const disposed = scene.dispose();
          scene.dispose();
          host.remove();
          results.push({
            ...disposed,
            peakTriangles: peak.peakTriangles,
            peakDrawCalls: peak.peakDrawCalls,
          });
          await new Promise((resolve) => setTimeout(resolve, 20));
        }
      } finally {
        globalThis.ResizeObserver = native;
      }
      return {
        results,
        observers: active.size,
        canvases: document.querySelectorAll("canvas").length,
      };
    });
    expect(results.observers).toBe(0);
    expect(results.canvases).toBe(0);
    expect(await counts()).toEqual(before);
    for (const r of results.results) {
      expect(r.geometries).toBe(0);
      expect(r.textures).toBe(0);
      expect(r.peakTriangles).toBeLessThanOrEqual(30000);
      expect(r.peakDrawCalls).toBeLessThanOrEqual(60);
      expect(r.dpr).toBeLessThanOrEqual(1.5);
      expect(r.particles).toBeLessThanOrEqual(128);
    }
    await info.attach("real-three-lifecycles", {
      body: JSON.stringify({
        ...results,
        listenersBefore: before,
        listenersAfter: await counts(),
      }),
      contentType: "application/json",
    });
    await cdp.send("Runtime.releaseObjectGroup", {
      objectGroup: "arena-lifecycle",
    });
  },
);
