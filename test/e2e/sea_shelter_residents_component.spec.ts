import { expect, test } from "@playwright/test";

test(
  "resident renderer releases animations, timers, observers and listeners across twenty lifecycles",
  async ({ page }, info) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await page.setViewportSize({ width: 320, height: 568 });
    await page.emulateMedia({ reducedMotion: "no-preference" });
    await page.goto("/labs/sea-shelter/index.html");
    await expect(page.locator(".crew-card")).toHaveCount(3);
    await page.locator('.tabs [data-view="residents"]').click();
    const cdp = await page.context().newCDPSession(page);
    const targets: string[] = [];
    for (const expression of ["window", "document"]) {
      const r = await cdp.send("Runtime.evaluate", {
        expression,
        objectGroup: "resident-lifecycle",
      });
      targets.push(r.result.objectId!);
    }
    const listeners = async () => {
      const counts: number[] = [];
      for (const objectId of targets) {
        counts.push(
          (await cdp.send("DOMDebugger.getEventListeners", { objectId }))
            .listeners.length,
        );
      }
      return counts;
    };
    const before = await listeners();
    const metrics = await page.evaluate(async () => {
      // Component contract test, distinct from the three user-visible I/O cases.
      const moduleUrl = "/labs/sea-shelter/residents.mjs";
      const { createResidentScene } = await import(moduleUrl);
      const intervals = new Set<number>(), timers = new Set<number>();
      const observers = new Set<ResizeObserver>();
      const native = {
        interval: globalThis.setInterval,
        clearInterval: globalThis.clearInterval,
        timeout: globalThis.setTimeout,
        clearTimeout: globalThis.clearTimeout,
        observer: globalThis.ResizeObserver,
      };
      globalThis.setInterval =
        ((handler: TimerHandler, delay?: number, ...args: unknown[]) => {
          const id = native.interval.call(globalThis, handler, delay, ...args);
          intervals.add(id);
          return id;
        }) as typeof globalThis.setInterval;
      globalThis.clearInterval = ((id?: number) => {
        if (id !== undefined) intervals.delete(id);
        native.clearInterval.call(globalThis, id);
      }) as typeof globalThis.clearInterval;
      globalThis.setTimeout =
        ((handler: TimerHandler, delay?: number, ...args: unknown[]) => {
          const id = native.timeout.call(globalThis, handler, delay, ...args);
          timers.add(id);
          return id;
        }) as typeof globalThis.setTimeout;
      globalThis.clearTimeout = ((id?: number) => {
        if (id !== undefined) timers.delete(id);
        native.clearTimeout.call(globalThis, id);
      }) as typeof globalThis.clearTimeout;
      globalThis.ResizeObserver = class extends native.observer {
        constructor(callback: ResizeObserverCallback) {
          super(callback);
          observers.add(this);
        }
        disconnect() {
          observers.delete(this);
          super.disconnect();
        }
      };
      let talksAfterDispose = 0, cycles = 0;
      const animationsBefore = document.getAnimations().length;
      try {
        for (let i = 0; i < 20; i++) {
          const main = document.createElement("div");
          main.dataset.view = "board";
          main.style.cssText =
            "position:absolute;left:-10000px;width:320px;height:320px";
          const play = document.createElement("div");
          play.style.cssText = "position:relative;width:300px;height:300px";
          const board = document.createElement("div");
          board.style.cssText = "width:246px;height:246px";
          const roster = document.createElement("div"),
            feedback = document.createElement("div");
          play.append(board);
          main.append(play, roster, feedback);
          document.body.append(main);
          let disposed = false;
          const scene = createResidentScene({
            main,
            board,
            play,
            roster,
            feedback,
            onTalk: () => {
              if (disposed) talksAfterDispose++;
            },
            onFlavor: () => {},
          });
          scene.update({
            residents: 3,
            claimed: [],
            tiles: [
              { x: 2, y: 2, kind: "dock" },
              { x: 1, y: 2, kind: "home" },
              { x: 2, y: 1, kind: "garden" },
            ],
          });
          if (
            main.querySelectorAll(".crew-actor").length !== 3 ||
            intervals.size !== 1
          ) throw Error("Component did not become active");
          const detachedCard = roster.querySelector("button")!;
          scene.react({ type: "collect" });
          disposed = true;
          scene.dispose();
          scene.dispose();
          detachedCard.click();
          if (main.querySelector(".crew-scene") || roster.children.length) {
            throw Error("Detached scene remains");
          }
          main.remove();
          cycles++;
        }
        return {
          cycles,
          intervals: intervals.size,
          timers: timers.size,
          observers: observers.size,
          talksAfterDispose,
          animationsBefore,
          animationsAfter: document.getAnimations().length,
        };
      } finally {
        globalThis.setInterval = native.interval;
        globalThis.clearInterval = native.clearInterval;
        globalThis.setTimeout = native.timeout;
        globalThis.clearTimeout = native.clearTimeout;
        globalThis.ResizeObserver = native.observer;
      }
    });
    expect(metrics.cycles).toBe(20);
    expect(metrics.intervals).toBe(0);
    expect(metrics.timers).toBe(0);
    expect(metrics.observers).toBe(0);
    expect(metrics.talksAfterDispose).toBe(0);
    expect(metrics.animationsAfter).toBe(metrics.animationsBefore);
    expect(await listeners()).toEqual(before);
    await info.attach("twenty-resident-lifecycles", {
      body: JSON.stringify({
        ...metrics,
        listenersBefore: before,
        listenersAfter: await listeners(),
      }),
      contentType: "application/json",
    });
    await cdp.send("Runtime.releaseObjectGroup", {
      objectGroup: "resident-lifecycle",
    });
    await cdp.detach();
    expect(errors).toEqual([]);
  },
);
